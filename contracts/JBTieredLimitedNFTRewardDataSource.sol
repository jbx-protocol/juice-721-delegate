// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBConstants.sol';
import '@openzeppelin/contracts/governance/utils/Votes.sol';
import './abstract/JBNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import './interfaces/ITokenSupplyDetails.sol';

/**
  @title
  JBTieredLimitedNFTRewardDataSource

  @notice
  Juicebox data source that offers NFTs to project contributors.

  @notice 
  This contract allows project creators to reward contributors with NFTs. 
  Intended use is to incentivize initial project support by minting a limited number of NFTs to the first N contributors among various price tiers.
*/
contract JBTieredLimitedNFTRewardDataSource is
  IJBTieredLimitedNFTRewardDataSource,
  ITokenSupplyDetails,
  JBNFTRewardDataSource,
  Votes
{
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INSUFFICIENT_AMOUNT();
  error OUT();
  error INSUFFICIENT_RESERVES();
  error INVALID_TIER();
  error NO_QUANTITY();
  error NOT_AVAILABLE();
  error TIER_LOCKED();
  error TIER_REMOVED();
  error VOTING_UNITS_NOT_ALLOWED();
  error RESERVED_RATE_NOT_ALLOWED();

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /** 
    @notice
    The token to expect contributions to be made in.
  */
  address public immutable override contributionToken;

  /** 
    @notice
    A flag indicating if contributions should mint NFTs if a tier's treshold is passed even if the tier ID isn't specified. 
  */
  bool public immutable override shouldMintByDefault;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /**
    @notice
    The common base for the tokenUri's

    @dev
    No setter to insure immutability
  */
  string public baseUri;

  /** 
    @notice
    The reward tier data. 

    _tierId The incremental ID of the tier, starting with 1.
  */
  mapping(uint256 => JBNFTRewardTierData) public tierData;

  /** 
    @notice
    Each account's balance within a specific tier.

    _account The address to get a balance for. 
    _tierId The ID of the tier to get a balance within.
  */
  mapping(address => mapping(uint256 => uint256)) public override tierBalanceOf;

  /**
    @notice 
    The number of reserved tokens that have been minted for each tier. 

    _tierId The ID of the tier to get a minted reserved token count for.
   */
  mapping(uint256 => uint256) public override numberOfReservesMintedFor;

  /** 
    @notice
    For each tier ID, a flag indicating if the tier has been paused. 

    _tierId The ID of the tier to check.
  */
  mapping(uint256 => bool) public override isTierRemoved;

  /** 
    @notice
    The total number of tiers there are. 
  */
  uint256 public override numberOfTiers;

  /** 
    @notice
    The beneficiary of reserved tokens.
  */
  address public override reservedTokenBeneficiary;

  //*********************************************************************//
  // ------------------- internal constant properties ------------------ //
  //*********************************************************************//

  /**
    @notice
    Just a kind reminder to our readers

    @dev
    Used in base58ToString
  */
  bytes internal constant _ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    Gets an array of all the tiers. 

    @return _tiers All the tiers tiers.
  */
  function tiers() external view override returns (JBNFTRewardTier[] memory _tiers) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    // Initialize an array with the appropriate length.
    _tiers = new JBNFTRewardTier[](_numberOfTiers);

    // Loop through each tier.
    for (uint256 _i; _i < _numberOfTiers; ) {
      // Add the tier to the array if it hasn't been removed.
      if (!isTierRemoved[_i])
        // Get a reference to the tier data (1-indexed).
        _tiers[_i] = JBNFTRewardTier({id: _i + 1, data: tierData[_i + 1]});

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Return the tier for the specified ID. 

    @param _id The ID of the tier to get. 
  */
  function tier(uint256 _id) external view override returns (JBNFTRewardTier memory _tier) {
    return JBNFTRewardTier({id: _id, data: tierData[_id]});
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply() external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData storage _data;

    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _data = tierData[_i];

      // Increment the total supply with the amount used already.
      supply += _data.initialQuantity - _data.remainingQuantity;

      unchecked {
        --_i;
      }
    }
  }

  /** 
    @notice 
    The total number of tokens with the given ID.
    @return Either 1 if the token has been minted, or 0 if it hasnt.
  */
  function tokenSupplyOf(uint256 _tokenId) external view override returns (uint256) {
    return ownerOf(_tokenId) != address(0) ? 1 : 0;
  }

  /** 
    @notice 
    The total number of tokens owned by the given owner. 
    @param _owner The address to check the balance of.
    @return The number of tokens owners by the owner.
  */
  function totalOwnerBalanceOf(address _owner) external view override returns (uint256) {
    return balanceOf(_owner);
  }

  /** 
    @notice 
    The total number of tokens with the given ID owned by the given owner. 
    @param _owner The address to check the balance of.
    @param _tokenId The ID of the token to check the owner's balance of.
    @return Either 1 if the owner has the token, or 0 if it does not.
  */
  function ownerTokenBalanceOf(address _owner, uint256 _tokenId)
    external
    view
    override
    returns (uint256)
  {
    return ownerOf(_tokenId) == _owner ? 1 : 0;
  }

  /** 
    @notice 
    The total number of tokens owned by the given owner. 

    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner accross all tiers.
  */
  function balanceOf(address _owner) public view override returns (uint256 balance) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    // Loop through all tiers.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      balance += tierBalanceOf[_owner][_i];

      unchecked {
        --_i;
      }
    }
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.

    @return The outstanding number of reserved tokens within the tier.
  */
  function numberOfReservedTokensOutstandingFor(uint256 _tierId)
    external
    view
    override
    returns (uint256)
  {
    return _numberOfReservedTokensOutstandingFor(_tierId, tierData[_tierId]);
  }

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _account The account to get voting units for.

    @return units The voting units for the account.
  */
  function getVotingUnits(address _account) external view virtual override returns (uint256 units) {
    return _getVotingUnits(_account);
  }

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The tier number of the provided token ID. 

    @dev
    Tier's are 1 indexed from the `tiers` array, meaning the 0th element of the array is tier 1.

    @param _tokenId The ID of the token to get the tier number of. 

    @return The tier number of the specified token ID.
  */
  function tierIdOfToken(uint256 _tokenId) public pure override returns (uint256) {
    // The tier ID is in the first 8 bits.
    return uint256(uint8(_tokenId));
  }

  /** 
    @notice
    TokenURI of the provided token ID.

    @dev
    Defer to the tokenUriResolver if set, otherwise, use the tokenUri set with the tier.

    @param _tokenId The ID of the token to get the tier tokenUri for. 

    @return The token URI corresponding with the tier or the tokenUriResolver URI.
  */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    // A token without an owner doesn't have a URI.
    if (_owners[_tokenId] == address(0)) return '';

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(tokenUriResolver) != address(0)) return tokenUriResolver.getUri(_tokenId);

    // Return the token URI for the token's tier.
    // return tiers[tierIdOfToken(_tokenId)].tokenUri;
    return _decodeIpfs(tierData[tierIdOfToken(_tokenId)].tokenUri);
  }

  /**
    @notice
    Indicates if this contract adheres to the specified interface.

    @dev 
    See {IERC165-supportsInterface}.

    @param _interfaceId The ID of the interface to check for adherance to.
  */
  function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
    return
      _interfaceId == type(IJBTieredLimitedNFTRewardDataSource).interfaceId ||
      _interfaceId == type(ITokenSupplyDetails).interfaceId ||
      super.supportsInterface(_interfaceId);
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projectId The ID of the project for which this NFT should be minted in response to payments made. 
    @param _directory The directory of terminals and controllers for projects.
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _owner The address that should own this contract.
    @param _tierData The tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _shouldMintByDefault A flag indicating if contributions should mint NFTs if a tier's treshold is passed even if the tier ID isn't specified. 
    @param _reservedTokenBeneficiary The address that should receive the reserved tokens.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    string memory _baseUri,
    address _owner,
    JBNFTRewardTierData[] memory _tierData,
    bool _shouldMintByDefault,
    address _reservedTokenBeneficiary
  )
    JBNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _contractUri,
      _owner
    )
    EIP712(_name, '1')
  {
    contributionToken = JBTokens.ETH;
    shouldMintByDefault = _shouldMintByDefault;
    baseUri = _baseUri;
    reservedTokenBeneficiary = _reservedTokenBeneficiary;

    _addTierData(_tierData, true);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mint a token within the tier for the provided value.

    @dev
    Only a project owner can mint tokens.

    @param _tierId The ID of the tier to mint within.
    @param _count The number of reserved tokens to mint. 
  */
  function mintReservesFor(uint256 _tierId, uint256 _count) external override {
    // Get a reference to the tier.
    JBNFTRewardTierData storage _data = tierData[_tierId];

    // Get a reference to the number of reserved tokens mintable for the tier.
    uint256 _numberOfReservedTokensOutstanding = _numberOfReservedTokensOutstandingFor(
      _tierId,
      _data
    );

    // Can't mint more reserves than expected.
    if (_count > _numberOfReservedTokensOutstanding) revert INSUFFICIENT_RESERVES();

    // Increment the number of reserved tokens minted.
    numberOfReservesMintedFor[_tierId] += _count;

    for (uint256 _i; _i < _count; ) {
      // Mint the tokens.
      uint256 _tokenId = _mintForTier(_tierId, _data, reservedTokenBeneficiary);

      emit MintReservedToken(_tokenId, _tierId, reservedTokenBeneficiary, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Adjust the tiers mintable in this contract, adhering to any locked tier constraints. 

    @param _tierDataToAdd An array of tier data to add.
    @param _tierIdsToRemove An array of tier IDs to remove.
  */
  function adjustTiers(
    JBNFTRewardTierData[] memory _tierDataToAdd,
    uint256[] memory _tierIdsToRemove
  ) external override onlyOwner {
    // Add tiers.
    if (_tierDataToAdd.length != 0) _addTierData(_tierDataToAdd, false);

    // Remove tiers.
    if (_tierIdsToRemove.length != 0) _removeTierIds(_tierIdsToRemove);
  }

  /** 
    @notice
    Sets the beneificiary of the reserved tokens. 

    @param _beneficiary The beneificiary of the reserved tokens.
  */
  function setReservedTokenBeneficiary(address _beneficiary) external override onlyOwner {
    // Set the beneficiary.
    reservedTokenBeneficiary = _beneficiary;

    emit SetReservedTokenBeneficiary(_beneficiary, msg.sender);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    Adds tiers. 

    @param _tierData The tiers to add.
    @param _constructorTiers A flag indicating if tiers with voting units and reserved rate should be allowed.
  */
  function _addTierData(JBNFTRewardTierData[] memory _tierData, bool _constructorTiers) internal {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Get a reference to the number of new tiers.
    uint256 _numberOfNewTiers = _tierData.length;

    // Get a reference to the current total number of tiers.
    uint256 _currentNumberOfTiers = numberOfTiers;

    for (uint256 _i = _numberOfNewTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _data = _tierData[_i - 1];

      // Make sure there are no voting units or reserved rates if they're not allowed.
      if (!_constructorTiers) {
        if (_data.votingUnits != 0) revert VOTING_UNITS_NOT_ALLOWED();
        if (_data.reservedRate != 0) revert RESERVED_RATE_NOT_ALLOWED();
      }

      // Make sure there is some quantity.
      if (_data.initialQuantity == 0) revert NO_QUANTITY();

      // Set the remaining quantity to be the initial quantity.
      _data.remainingQuantity = _data.initialQuantity;

      // Get a reference to the tier ID.
      uint256 _tierId = _currentNumberOfTiers + _i;

      // Add the tier with the iterative ID.
      tierData[_tierId] = _data;

      emit AddTier(_tierId, _data, msg.sender);

      unchecked {
        --_i;
      }
    }

    numberOfTiers = _currentNumberOfTiers + _numberOfNewTiers;
  }

  /** 
    @notice
    Remove tiers. 

    @param _tierIds The tiers IDs to remove.
  */
  function _removeTierIds(uint256[] memory _tierIds) internal {
    // Get a reference to the number of tiers being removed.
    uint256 _numTiers = _tierIds.length;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on.
      // Input is 1-indexed but storage uses 0-index so we lower by 1
      _tierId = _tierIds[_i] - 1;

      // If the tier is locked throw an error.
      if (tierData[_tierId].lockedUntil >= block.timestamp) revert TIER_LOCKED();

      // Set the tier as removed.
      isTierRemoved[_tierId] = true;

      emit RemoveTier(_tierId, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /**
    @notice 
    Mints a token for a given contribution to the beneficiary.

    @dev
    `_data.metadata` should include the reward tiers being requested in increments of 8 bits starting at bits 32.

    @param _data The Juicebox standard project contribution data.
  */
  function _processContribution(JBDidPayData calldata _data) internal override {
    // Make sure the contribution is being made in the expected token.
    if (_data.amount.token != contributionToken) return;

    // Check if the metadata is filled with the needed information
    if (_data.metadata.length > 32) {
      // Decode the metadata, Skip the first 32 bits which are used by the JB protocol.
      (, uint8[] memory _decodedMetadata) = abi.decode(_data.metadata, (bytes32, uint8[]));

      // Mint rewards if they were specified. If there are no rewards but a default NFT should be minted, do so.
      if (_decodedMetadata.length != 0)
        return _mintAll(_data.amount.value, _decodedMetadata, _data.beneficiary);
    }

    // Fallback for if we were not able to mint using the metadata
    if (shouldMintByDefault) return _mintBestAvailableTier(_data.amount.value, _data.beneficiary);
  }

  /** 
    @notice
    Mints a token in the best available tier.

    @param _amount The amount to base the mint on.
    @param _beneficiary The address to mint for.
  */
  function _mintBestAvailableTier(uint256 _amount, address _beneficiary) internal {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Keep a reference to the best available tier.
    uint256 _bestContributionFloor;

    // Keep a reference to the best tier's ID.
    uint256 _bestTierId;

    // Loop through each tier and keep track of the best option.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      if (!isTierRemoved[_i]) {
        // Set the tier being iterated on. Tier's are 1 indexed.
        _data = tierData[_i];

        // Mint if the contribution value is at least as much as the floor, there's sufficient supply, and the floor is better than the best tier.
        if (
          _data.contributionFloor > _bestContributionFloor &&
          _data.contributionFloor <= _amount &&
          (_data.remainingQuantity - _numberOfReservedTokensOutstandingFor(_i, _data)) != 0
        ) {
          _bestContributionFloor = _data.contributionFloor;
          _bestTierId = _i;
        }
      }

      unchecked {
        --_i;
      }
    }

    // If there's no best tier, return.
    if (_bestTierId == 0) return;

    // Keep a reference to the best tier.
    JBNFTRewardTierData storage _bestTierData = tierData[_bestTierId];

    // Mint the tokens.
    uint256 _tokenId = _mintForTier(_bestTierId, _bestTierData, _beneficiary);

    emit Mint(_tokenId, _bestTierId, _beneficiary, _amount, 0, msg.sender);
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _mintTiers An array of tierIds that the user wants to mint
    @param _beneficiary The address to mint for.
  */
  function _mintAll(
    uint256 _amount,
    uint8[] memory _mintTiers,
    address _beneficiary
  ) internal {
    // Keep a reference to the amount remaining.
    uint256 _remainingValue = _amount;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData storage _data;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    uint256 _mintsLength = _mintTiers.length;

    for (uint256 _i; _i < _mintsLength; ) {
      // Get a reference to the tier being iterated on.
      _tierId = _mintTiers[_i];

      // Make sure the tier hasn't been removed.
      if (isTierRemoved[_tierId]) revert TIER_REMOVED();

      // If a tier specified, accept the funds and mint.
      if (_tierId != 0) {
        // Keep a reference to the tier being iterated on.
        _data = tierData[_tierId];

        // Make sure the provided tier exists.
        if (_data.initialQuantity == 0) revert INVALID_TIER();

        // Make sure the amount meets the tier's contribution floor.
        if (_data.contributionFloor > _remainingValue) revert INSUFFICIENT_AMOUNT();

        // Make sure there are enough units available.
        if (_data.remainingQuantity - _numberOfReservedTokensOutstandingFor(_tierId, _data) == 0)
          revert OUT();

        // Mint the tokens.
        uint256 _tokenId = _mintForTier(_tierId, _data, _beneficiary);

        // Decrement the remaining value.
        _remainingValue = _remainingValue - _data.contributionFloor;

        emit Mint(_tokenId, _tierId, _beneficiary, _amount, _mintsLength, msg.sender);
      }

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Mints a token in a tier for a specific benficiary.

    @param _tierId The ID of the tier to mint within.
    @param _data The tier data to mint for.
    @param _beneficiary The address to mint for.

    @return tokenId The ID of the token minted.
  */
  function _mintForTier(
    uint256 _tierId,
    JBNFTRewardTierData storage _data,
    address _beneficiary
  ) internal returns (uint256 tokenId) {
    unchecked {
      // Keep a reference to the token ID.
      tokenId = _generateTokenId(_tierId, _data.initialQuantity - --_data.remainingQuantity);
    }

    // Increment the tier balance for the beneficiary.
    ++tierBalanceOf[_beneficiary][_tierId];

    // Mint the token.
    _mint(_beneficiary, tokenId);
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.
    @param _data The tier data to get a number of reserved tokens outstanding.

    @return numberReservedTokensOutstanding The outstanding number of reserved tokens within the tier.
  */
  function _numberOfReservedTokensOutstandingFor(uint256 _tierId, JBNFTRewardTierData memory _data)
    internal
    view
    returns (uint256)
  {
    // Invalid tier or no reserved rate?
    if (_data.initialQuantity == 0 || _data.reservedRate == 0) return 0;

    // No token minted yet? Round up to 1
    if (_data.initialQuantity == _data.remainingQuantity) return 1;

    // The number of reserved token of the tier already minted
    uint256 reserveTokensMinted = numberOfReservesMintedFor[_tierId];

    // Get a reference to the number of tokens already minted in the tier, not counting reserves.
    uint256 _numberOfNonReservesMinted = _data.initialQuantity -
      _data.remainingQuantity -
      reserveTokensMinted;

    // Store the numerator common to the next two calculations.
    uint256 _numerator = uint256(_numberOfNonReservesMinted * _data.reservedRate);

    // Get the number of reserved tokens mintable given the number of non reserved tokens minted. This will round down.
    uint256 _numberReservedTokensMintable = _numerator / JBConstants.MAX_RESERVED_RATE;

    // Round up.
    if (_numerator - JBConstants.MAX_RESERVED_RATE * _numberReservedTokensMintable > 0)
      ++_numberReservedTokensMintable;

    // Return the difference between the amount mintable and the amount already minted.
    return _numberReservedTokensMintable - reserveTokensMinted;
  }

  /** 
    @notice
    Finds the token ID and tier given a contribution amount. 

    @param _tierId The ID of the tier to generate an ID for.
    @param _tokenNumber The number of the token in the tier.

    @return tokenId The ID of the token.
  */
  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber)
    internal
    pure
    returns (uint256 tokenId)
  {
    // The tier ID in the first 8 bits.
    tokenId = _tierId;

    // The token number in the rest.
    tokenId |= _tokenNumber << 8;
  }

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _account The account to get voting units for.

    @return units The voting units for the account.
  */
  function _getVotingUnits(address _account)
    internal
    view
    virtual
    override
    returns (uint256 units)
  {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers;

    // Loop through all tiers.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      uint256 _balance = tierBalanceOf[_account][_i];

      if (_balance != 0)
        // Add the tier's voting units.
        units += _balance * tierData[_i].votingUnits;

      unchecked {
        --_i;
      }
    }
  }

  /**
    @notice
    Transfer voting units after the transfer of a token.

    @param _from The address where the transfer is originating.
    @param _to The address to which the transfer is being made.
    @param _tokenId The ID of the token being transfered.
   */
  function _afterTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal virtual override {
    // Get a reference to the tier.
    JBNFTRewardTierData memory _data = tierData[tierIdOfToken(_tokenId)];

    if (_data.votingUnits > 0)
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _data.votingUnits);

    super._afterTokenTransfer(_from, _to, _tokenId);
  }

  function _decodeIpfs(bytes32 hexString) internal view returns (string memory) {
    // Concatenate the hex string with the fixed IPFS hash part (0x12 and 0x20)
    bytes memory completeHexString = abi.encodePacked(bytes2(0x1220), hexString);

    // Convert the hex string to an hash
    string memory ipfsHash = _toBase58(completeHexString);

    // Concatenate with the base URI
    return string(abi.encodePacked(baseUri, ipfsHash));
  }

  /**
    @notice
    Convert an hex string to base58

    @notice 
    Written by Martin Ludfall - Licence: MIT
  */
  function _toBase58(bytes memory source) internal pure returns (string memory) {
    if (source.length == 0) return new string(0);
    uint8[] memory digits = new uint8[](46); // hash size with the prefix
    digits[0] = 0;
    uint8 digitlength = 1;
    for (uint256 i = 0; i < source.length; ++i) {
      uint256 carry = uint8(source[i]);
      for (uint256 j = 0; j < digitlength; ++j) {
        carry += uint256(digits[j]) * 256;
        digits[j] = uint8(carry % 58);
        carry = carry / 58;
      }

      while (carry > 0) {
        digits[digitlength] = uint8(carry % 58);
        digitlength++;
        carry = carry / 58;
      }
    }
    return string(_toAlphabet(_reverse(_truncate(digits, digitlength))));
  }

  function _truncate(uint8[] memory array, uint8 length) internal pure returns (uint8[] memory) {
    uint8[] memory output = new uint8[](length);
    for (uint256 i = 0; i < length; i++) {
      output[i] = array[i];
    }
    return output;
  }

  function _reverse(uint8[] memory input) internal pure returns (uint8[] memory) {
    uint8[] memory output = new uint8[](input.length);
    for (uint256 i = 0; i < input.length; i++) {
      output[i] = input[input.length - 1 - i];
    }
    return output;
  }

  function _toAlphabet(uint8[] memory indices) internal pure returns (bytes memory) {
    bytes memory output = new bytes(indices.length);
    for (uint256 i = 0; i < indices.length; i++) {
      output[i] = _ALPHABET[indices[i]];
    }
    return output;
  }
}
