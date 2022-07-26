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
  error INVALID_PRICE_SORT_ORDER();
  error NO_QUANTITY();
  error NOT_AVAILABLE();

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
    The total number of tiers there are. 
  */
  uint256 public immutable override numberOfTiers;

  /** 
    @notice
    A flag indicating if contributions should mint NFTs if a tier's treshold is passed even if the tier ID isn't specified. 
  */
  bool public immutable override shouldMintByDefault;

  //*********************************************************************//
  // --------------- internal immutable stored properties -------------- //
  //*********************************************************************//

  /**
    @notice
    Just a kind reminder to our readers

    @dev
    Used in base58ToString
  */
  bytes internal constant _ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /**
    @notice
    The common base for the tokenUri's

    @dev
    No setter to insure immutability
  */
  string internal baseUri;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice
    The reward tiers. 

    _tierId The incremental ID of the tier. Ordered by contribution floor, starting with 1.
  */
  mapping(uint256 => JBNFTRewardTier) public tiers;

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
    The beneficiary of reserved tokens.
  */
  address public override reservedTokenBeneficiary;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    Gets an array of all the tiers. 

    @return _tiers All the tiers tiers.
  */
  function allTiers() external view override returns (JBNFTRewardTier[] memory _tiers) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    // Initialize an array with the appropriate length.
    _tiers = new JBNFTRewardTier[](_numberOfTiers);

    // Loop through each tier.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Add the tier to the array.
      _tiers[_i - 1] = tiers[_i];

      unchecked {
        --_i;
      }
    }
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply() external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier storage _tier;

    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _tier = tiers[_i];

      // Increment the total supply with the amount used already.
      supply += _tier.initialQuantity - _tier.remainingQuantity;

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
    return _numberOfReservedTokensOutstandingFor(_tierId, tiers[_tierId]);
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
    return _decodeIpfs(tiers[tierIdOfToken(_tokenId)].tokenUri);
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
    @param _tiers The tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
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
    JBNFTRewardTier[] memory _tiers,
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

    // Get a reference to the number of tiers.
    uint256 _numberOfTiers = _tiers.length;

    numberOfTiers = _numberOfTiers;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    for (uint256 _i; _i < _numberOfTiers; ) {
      // Set the tier being iterated on.
      _tier = _tiers[_i];

      // Make sure there is some quantity.
      if (_tier.remainingQuantity == 0) revert NO_QUANTITY();

      // Make sure the tier's contribution floor is greater than or equal to the previous contribution floor.
      if (_i != 0 && _tier.contributionFloor < _tiers[_i - 1].contributionFloor)
        revert INVALID_PRICE_SORT_ORDER();

      // Set the remaining quantity to be the initial quantity.
      _tier.remainingQuantity = _tier.initialQuantity;

      // Add the tier with the iterative ID.
      tiers[_i + 1] = _tier;

      unchecked {
        ++_i;
      }
    }
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
    JBNFTRewardTier storage _tier = tiers[_tierId];

    // Get a reference to the number of reserved tokens mintable for the tier.
    uint256 _numberOfReservedTokensOutstanding = _numberOfReservedTokensOutstandingFor(
      _tierId,
      _tier
    );

    // Can't mint more reserves than expected.
    if (_count > _numberOfReservedTokensOutstanding) revert INSUFFICIENT_RESERVES();

    // Increment the number of reserved tokens minted.
    numberOfReservesMintedFor[_tierId] += _count;

    for (uint256 _i; _i < _count; ) {
      // Mint the tokens.
      uint256 _tokenId = _mintForTier(_tierId, _tier, reservedTokenBeneficiary);

      emit MintReservedToken(_tokenId, _tierId, reservedTokenBeneficiary, msg.sender);

      unchecked {
        ++_i;
      }
    }
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
    if (shouldMintByDefault) {
      bool out = _mintBestAvailableTier(_data.amount.value, _data.beneficiary);
      if (out) revert OUT();
    }
  }

  /** 
    @notice
    Mints a token in the best available tier.

    @param _amount The amount to base the mint on.
    @param _beneficiary The address to mint for.

    @return Flag indicating if the contract does not have any NFTs available for the `_amount`
  */
  function _mintBestAvailableTier(uint256 _amount, address _beneficiary)
    internal
    returns (bool)
  {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier storage _tier;

    // Loop through each tier. Go from most valuable tier to least valuable.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Set the tier being iterated on. Tier's are 1 indexed.
      _tier = tiers[_i];

      // Mint if the contribution value is at least as much as the floor, there's sufficient supply.
      if (_tier.contributionFloor <= _amount) {
        if ((_tier.remainingQuantity - _numberOfReservedTokensOutstandingFor(_i, _tier)) != 0) {
          // Mint the tokens.
          uint256 _tokenId = _mintForTier(_i, _tier, _beneficiary);

          emit Mint(_tokenId, _i, _beneficiary, _amount, 0, msg.sender);

          return false;
        }
      }

      unchecked {
        --_i;
      }
    }

    // Nothing was minted
    return true;
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
    JBNFTRewardTier storage _tier;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    uint256 _mintsLength = _mintTiers.length;

    for (uint256 _i; _i < _mintsLength; ) {
      // Get a reference to the tier being iterated on.
      _tierId = _mintTiers[_i];

      // If a tier specified, accept the funds and mint.
      if (_tierId != 0) {
        // Keep a reference to the tier being iterated on.
        _tier = tiers[_tierId];

        // Make sure the provided tier exists.
        if (_tier.initialQuantity == 0) revert INVALID_TIER();

        // Make sure the amount meets the tier's contribution floor.
        if (_tier.contributionFloor > _remainingValue) revert INSUFFICIENT_AMOUNT();

        // Make sure there are enough units available.
        if (_tier.remainingQuantity - _numberOfReservedTokensOutstandingFor(_tierId, _tier) == 0)
          revert OUT();

        // Mint the tokens.
        uint256 _tokenId = _mintForTier(_tierId, _tier, _beneficiary);

        // Decrement the remaining value.
        _remainingValue = _remainingValue - _tier.contributionFloor;

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
    @param _tier The tier structure to mint for.
    @param _beneficiary The address to mint for.

    @return tokenId The ID of the token minted.
  */
  function _mintForTier(
    uint256 _tierId,
    JBNFTRewardTier storage _tier,
    address _beneficiary
  ) internal returns (uint256 tokenId) {
    unchecked {
      // Keep a reference to the token ID.
      tokenId = _generateTokenId(_tierId, _tier.initialQuantity - --_tier.remainingQuantity);
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
    @param _tier The tier structure to get a number of reserved tokens outstanding.

    @return numberReservedTokensOutstanding The outstanding number of reserved tokens within the tier.
  */
  function _numberOfReservedTokensOutstandingFor(uint256 _tierId, JBNFTRewardTier memory _tier)
    internal
    view
    returns (uint256)
  {
    // Invalid tier or no reserved rate?
    if (_tier.initialQuantity == 0 || _tier.reservedRate == 0) return 0;

    // No token minted yet? Round up to 1
    if (_tier.initialQuantity == _tier.remainingQuantity) return 1;

    // The number of reserved token of the tier already minted
    uint256 reserveTokensMinted = numberOfReservesMintedFor[_tierId];

    // Get a reference to the number of tokens already minted in the tier, not counting reserves.
    uint256 _numberOfNonReservesMinted = _tier.initialQuantity -
      _tier.remainingQuantity -
      reserveTokensMinted;

    // Store the numerator common to the next two calculations.
    uint256 _numerator = uint256(_numberOfNonReservesMinted * _tier.reservedRate);

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
        units += _balance * tiers[_i].votingUnits;

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
    JBNFTRewardTier memory _tier = tiers[tierIdOfToken(_tokenId)];

    if (_tier.votingUnits > 0)
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _tier.votingUnits);

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
