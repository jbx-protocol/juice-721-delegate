// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBConstants.sol';
import '@openzeppelin/contracts/governance/utils/Votes.sol';
import './abstract/JBNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import './interfaces/ITokenSupplyDetails.sol';
import './structs/JBStoredNFTRewardTier.sol';

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
  error OVERSPENDING();
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
  // --------------------- internal stored properties ------------------ //
  //*********************************************************************//

  /**
    @notice
    When using this contract to manage token uri's, those are stored as 32bytes, based on IPFS
    hashes stripped down

    _tierId the ID of the tier
  */
  mapping(uint256 => bytes32) internal _encodedIpfsUriOf;

  /**
    @notice
    An optionnal beneficiary for the reserved token of a given tier.

    _tierId the ID of the tier.
  */
  mapping(uint256 => address) internal _reservedTokenBeneficiaryOf;

  /** 
    @notice
    The stored reward tier data. 

    _tierId The incremental ID of the tier, starting with 1.
  */
  mapping(uint256 => JBStoredNFTRewardTier) internal _storedTeirOf;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    Gets an array of all the active tiers. 

    @return _tiers All the tiers.
  */
  function tiers() external view override returns (JBNFTRewardTier[] memory _tiers) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    // Initialize an array with the appropriate length.
    _tiers = new JBNFTRewardTier[](_numberOfTiers);

    // Count the number of active tiers
    uint256 _activeTiers;

    // Loop through each tier.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Add the tier to the array if it hasn't been removed (tiers are unsorted)
      if (!isTierRemoved[_i]) {
        // Get a reference to the tier data (1-indexed). Overwrite empty tiers.
        _tiers[_activeTiers] = _getStructWith(_i, true, true);
        unchecked {
          ++_activeTiers;
        }
      }

      unchecked {
        --_i;
      }
    }

    // Resize the array if there are removed tiers
    if (_activeTiers != _numberOfTiers)
      assembly {
        mstore(_tiers, _activeTiers)
      }
  }

  /** 
    @notice
    Return the tier for the specified ID. 

    @param _id The ID of the tier to get. 
  */
  function tierWith(uint256 _id) external view override returns (JBNFTRewardTier memory _tier) {
    return _getStructWith(_id, true, true);
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply() external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers;

    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _tier = _getStructWith(_i, false, false);

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
    return _numberOfReservedTokensOutstandingFor(_tierId, _getStructWith(_tierId, false, false));
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
    return _decodeIpfs(_encodedIpfsUriOf[tierIdOfToken(_tokenId)]);
  }

  /** 
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `totalRedemptionWeight`. 

    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return weight The weight.
  */
  function redemptionWeightOf(uint256[] memory _tokenIds)
    public
    view
    override
    returns (uint256 weight)
  {
    // Get a reference to the total number of tokens.
    uint256 _numberOfTokenIds = _tokenIds.length;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _numberOfTokenIds; ) {
      weight += uint256(tierData[tierIdOfToken(_tokenIds[_i])].contributionFloor);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    The cumulative weight that all token IDs have in redemptions. 

    @return weight The total weight.
  */
  function totalRedemptionWeight() public view override returns (uint256 weight) {
    // Get a reference to the total number of tiers.
    uint256 _numberOfTiers = numberOfTiers;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _numberOfTiers; ) {
      _data = tierData[_i + 1];

      // Add the tier's contribution floor multiplied by the quantity minted.
      weight +=
        (uint256(_data.contributionFloor) * (_data.initialQuantity - _data.remainingQuantity)) +
        _numberOfReservedTokensOutstandingFor(_i, _data);

      unchecked {
        ++_i;
      }
    }
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
    JBNFTRewardTierParams[] memory _tiers,
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
    baseUri = _baseUri;
    reservedTokenBeneficiary = _reservedTokenBeneficiary;

    _addTiers(_tiers, true);
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
    JBNFTRewardTier memory _tier = _getStructWith(_tierId, true, false);

    // Get a reference to the number of reserved tokens mintable for the tier.
    uint256 _numberOfReservedTokensOutstanding = _numberOfReservedTokensOutstandingFor(
      _tierId,
      _tier
    );

    // Can't mint more reserves than expected.
    if (_count > _numberOfReservedTokensOutstanding) revert INSUFFICIENT_RESERVES();

    // Increment the number of reserved tokens minted.
    numberOfReservesMintedFor[_tierId] += _count;

    // Get a reference to the beneficiary.
    address _beneficiary = _tier.reservedTokenBeneficiary != address(0)
      ? _tier.reservedTokenBeneficiary
      : reservedTokenBeneficiary;

    for (uint256 _i; _i < _count; ) {
      // Mint the tokens.
      uint256 _tokenId = _mintForTier(_tier, _beneficiary);

      emit MintReservedToken(_tokenId, _tierId, _beneficiary, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Adjust the tiers mintable in this contract, adhering to any locked tier constraints. 

    @param _tiersToAdd An array of tier data to add.
    @param _tierIdsToRemove An array of tier IDs to remove.
  */
  function adjustTiers(
    JBNFTRewardTierParams[] memory _tiersToAdd,
    uint256[] memory _tierIdsToRemove
  ) external override onlyOwner {
    // Add tiers.
    if (_tiersToAdd.length != 0) _addTiers(_tiersToAdd, false);

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

    @param _tiers The tiers to add.
    @param _constructorTiers A flag indicating if tiers with voting units and reserved rate should be allowed.
  */
  function _addTiers(JBNFTRewardTierParams[] memory _tiers, bool _constructorTiers) internal {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierParams memory _tier;

    // Get a reference to the number of new tiers.
    uint256 _numberOfNewTiers = _tiers.length;

    // Get a reference to the current total number of tiers.
    uint256 _currentNumberOfTiers = numberOfTiers;

    for (uint256 _i = _numberOfNewTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _tier = _tiers[_i - 1];

      // Make sure there are no voting units or reserved rates if they're not allowed.
      if (!_constructorTiers) {
        if (_tier.votingUnits != 0) revert VOTING_UNITS_NOT_ALLOWED();
        if (_tier.reservedRate != 0) revert RESERVED_RATE_NOT_ALLOWED();
      }

      // Make sure there is some quantity.
      if (_tier.initialQuantity == 0) revert NO_QUANTITY();

      // Set the remaining quantity to be the initial quantity.
      _tier.remainingQuantity = _tier.initialQuantity;

      // Get a reference to the tier ID.
      uint256 _tierId = _currentNumberOfTiers + _i;

      // Store the tier.
      _storedTeirOf[_tierId] = JBStoredNFTRewardTier(
        uint80(_tier.contributionFloor),
        uint48(_tier.lockedUntil),
        uint48(_tier.remainingQuantity),
        uint48(_tier.initialQuantity),
        uint16(_tier.votingUnits),
        uint16(_tier.reservedRate)
      );

      // Add the corresponding reserved token beneficiary if there is one.
      if (_tier.reservedTokenBeneficiary != address(0))
        _reservedTokenBeneficiaryOf[_tierId] = _tier.reservedTokenBeneficiary;

      // Add the corresponding ipfs uri if there is one.
      if (_tier.encodedIPFSUri != bytes32(0)) _encodedIpfsUriOf[_tierId] = _tier.encodedIPFSUri;

      emit AddTier(_tierId, _tier, msg.sender);

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
      // Set the tier being iterated on, 0-indexed
      _tierId = _tierIds[_i];

      // If the tier is locked throw an error.
      if (_getStructWith(_tierId, false, false).lockedUntil >= block.timestamp)
        revert TIER_LOCKED();

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

    // Set the leftover amount as the initial value.
    uint256 _leftoverAmount = _data.amount.value;

    // Keep a reference to a flag indicating if a mint is expected from discretionary funds. Defaults to false, meaning to mint is expected.
    bool _expectMintFromExtraFunds;

    // Keep a reference to the flag indicating if funds should be refunded if not spent. Defaults to false, meaning no funds will be returned.
    bool _dontOverspend;

    // skip the first 32 bits which are used by the JB protocol to pass the paying project's ID when paying from a JBSplit.
    // Check the 4 bits interfaceId to verify the metadata is intended for this contract
    if (
      _data.metadata.length > 36 &&
      bytes4(_data.metadata[32:36]) == type(IJBNFTRewardDataSource).interfaceId
    ) {
      // Keep references to the metadata properties.
      bool _dontMint;
      uint8[] memory _tierIdsToMint;

      // Decode the metadata
      (, , _dontMint, _expectMintFromExtraFunds, _dontOverspend, _tierIdsToMint) = abi.decode(
        _data.metadata,
        (bytes32, bytes4, bool, bool, bool, uint8[])
      );

      // Don't mint if not desired.
      if (_dontMint) return;

      // Mint rewards if they were specified. If there are no rewards but a default NFT should be minted, do so.
      if (_tierIdsToMint.length != 0)
        _leftoverAmount = _mintAll(_leftoverAmount, _tierIdsToMint, _data.beneficiary);
    }

    // If there are funds leftover, mint the best available with it.
    if (_leftoverAmount != 0)
      _leftoverAmount = _mintBestAvailableTier(
        _leftoverAmount,
        _data.beneficiary,
        _expectMintFromExtraFunds
      );

    // Make sure there are no leftover funds after minting if not expected.
    if (_dontOverspend && _leftoverAmount != 0) revert OVERSPENDING();
  }

  /** 
    @notice
    Mints a token in the best available tier.

    @param _amount The amount to base the mint on.
    @param _beneficiary The address to mint for.
    @param _expectMint A flag indicating if a mint was expected.

    @return  The amount leftover after the mint.
  */
  function _mintBestAvailableTier(
    uint256 _amount,
    address _beneficiary,
    bool _expectMint
  ) internal returns (uint256) {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    // Keep a reference to the best available tier.
    uint256 _bestContributionFloor;

    // Keep a reference to the best tier's ID.
    uint256 _bestTierId;

    // Loop through each tier and keep track of the best option.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      if (!isTierRemoved[_i]) {
        // Set the tier being iterated on. Tier's are 1 indexed.
        _tier = _getStructWith(_i, false, false);

        // Mint if the contribution value is at least as much as the floor, there's sufficient supply, and the floor is better than the best tier.
        if (
          _tier.contributionFloor > _bestContributionFloor &&
          _tier.contributionFloor <= _amount &&
          (_tier.remainingQuantity - _numberOfReservedTokensOutstandingFor(_i, _tier)) != 0
        ) {
          _bestContributionFloor = _tier.contributionFloor;
          _bestTierId = _i;
        }
      }

      unchecked {
        --_i;
      }
    }

    // If there's no best tier, return.
    if (_bestTierId == 0) {
      // Make sure a mint was not expected.
      if (_expectMint) revert NOT_AVAILABLE();
      return _amount;
    }

    // Keep a reference to the best tier.
    JBNFTRewardTier memory _bestTier = _getStructWith(_bestTierId, false, false);

    // Mint the tokens.
    uint256 _tokenId = _mintForTier(_bestTier, _beneficiary);

    emit Mint(_tokenId, _bestTierId, _beneficiary, _bestContributionFloor, 0, msg.sender);

    // Return the leftover amount.
    return _amount - _bestContributionFloor;
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _mintTiers An array of tierIds that the user wants to mint
    @param _beneficiary The address to mint for.

    @return leftoverAmount The amount leftover after the mint.
  */
  function _mintAll(
    uint256 _amount,
    uint8[] memory _mintTiers,
    address _beneficiary
  ) internal returns (uint256 leftoverAmount) {
    // Set the leftover amount to be the initial amount.
    leftoverAmount = _amount;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

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
        _tier = _getStructWith(_tierId, false, false);

        // Make sure the provided tier exists.
        if (_tier.initialQuantity == 0) revert INVALID_TIER();

        // Make sure the amount meets the tier's contribution floor.
        if (_tier.contributionFloor > leftoverAmount) revert INSUFFICIENT_AMOUNT();

        // Make sure there are enough units available.
        if (_tier.remainingQuantity - _numberOfReservedTokensOutstandingFor(_tierId, _tier) == 0)
          revert OUT();

        // Mint the tokens.
        uint256 _tokenId = _mintForTier(_tier, _beneficiary);

        // Decrement the leftover amount.
        leftoverAmount = leftoverAmount - _tier.contributionFloor;

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

    @param _tier The tier data to mint for.
    @param _beneficiary The address to mint for.

    @return tokenId The ID of the token minted.
  */
  function _mintForTier(JBNFTRewardTier memory _tier, address _beneficiary)
    internal
    returns (uint256 tokenId)
  {
    unchecked {
      // Decrease the remaining quantity.
      _storedTeirOf[_tier.id].remainingQuantity = uint48(--_tier.remainingQuantity);

      // Keep a reference to the token ID.
      tokenId = _generateTokenId(_tier.id, _tier.initialQuantity - _tier.remainingQuantity);
    }

    // Increment the tier balance for the beneficiary.
    ++tierBalanceOf[_beneficiary][_tier.id];

    // Mint the token.
    _mint(_beneficiary, tokenId);
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.
    @param _tier The tier to get a number of reserved tokens outstanding.

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
        units += _balance * _getStructWith(_i, false, false).votingUnits;

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
    JBNFTRewardTier memory _tier = _getStructWith(tierIdOfToken(_tokenId), false, false);

    if (_tier.votingUnits > 0)
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _tier.votingUnits);

    super._afterTokenTransfer(_from, _to, _tokenId);
  }

  /** 
    @notice
    Unpack a tier's packed stored values into an easy-to-work-with tier struct.

    @param _tierId The ID of the tier struct to get.
    @param _includeReservedTokenBeneficiary A flag indicating if the reserved token beneficiary should be included.
    @param _includeEncodedIpfsUri A flag indicating if the IPFS uri should be included.

    @return tier tier struct. 
  */
  function _getStructWith(
    uint256 _tierId,
    bool _includeReservedTokenBeneficiary,
    bool _includeEncodedIpfsUri
  ) internal view returns (JBNFTRewardTier memory tier) {
    JBStoredNFTRewardTier memory _storedTier = _storedTeirOf[_tierId];

    // Set the ID.
    tier.id = _tierId;

    tier.contributionFloor = uint256(_storedTier.contributionFloor);
    tier.lockedUntil = uint256(_storedTier.lockedUntil);
    tier.remainingQuantity = uint256(_storedTier.remainingQuantity);
    tier.initialQuantity = uint256(_storedTier.initialQuantity);
    tier.votingUnits = uint256(_storedTier.votingUnits);
    tier.reservedRate = uint256(_storedTier.reservedRate);

    // Include the reserved token beneficiary if needed.
    if (_includeReservedTokenBeneficiary)
      tier.reservedTokenBeneficiary = _reservedTokenBeneficiaryOf[_tierId];

    // Includet eh ipfs uri if needed.
    if (_includeEncodedIpfsUri) tier.encodedIPFSUri = _encodedIpfsUriOf[_tierId];
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
