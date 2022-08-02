// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/libraries/JBConstants.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSourceStore.sol';

/**
  @title
  JBTieredLimitedNFTRewardDataSourceStore
*/
contract JBTieredLimitedNFTRewardDataSourceStore is IJBTieredLimitedNFTRewardDataSourceStore {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INSUFFICIENT_AMOUNT();
  error INSUFFICIENT_RESERVES();
  error INVALID_TIER();
  error NO_QUANTITY();
  error NOT_AVAILABLE();
  error OUT();
  error RESERVED_RATE_NOT_ALLOWED();
  error TIER_LOCKED();
  error TIER_REMOVED();
  error VOTING_UNITS_NOT_ALLOWED();

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice
    The total number of tiers there are. 

    _nft The NFT contract to get the number of tiers of.
  */
  mapping(address => uint256) public override numberOfTiers;

  /** 
    @notice
    The reward tier data. 

    _nft The NFT contract to which the tier data belong.
    _tierId The incremental ID of the tier, starting with 1.
  */
  mapping(address => mapping(uint256 => JBNFTRewardTierData)) public tierData;

  /** 
    @notice
    Each account's balance within a specific tier.

    _nft The NFT contract to which the tier data belong.
    _owner The address to get a balance for. 
    _tierId The ID of the tier to get a balance within.
  */
  mapping(address => mapping(address => mapping(uint256 => uint256))) public override tierBalanceOf;

  /**
    @notice 
    The number of reserved tokens that have been minted for each tier. 

    _nft The NFT contract to which the tier data belong.
    _tierId The ID of the tier to get a minted reserved token count for.
   */
  mapping(address => mapping(uint256 => uint256)) public override numberOfReservesMintedFor;

  /** 
    @notice
    For each tier ID, a flag indicating if the tier has been paused. 

    _nft The NFT contract to which the tier data belong.
    _tierId The ID of the tier to check.
  */
  mapping(address => mapping(uint256 => bool)) public override isTierRemoved;

  /** 
    @notice
    The beneficiary of reserved tokens.

    _nft The NFT contract to which the reserved token beneficiary applies.
  */
  mapping(address => address) public override reservedTokenBeneficiary;

  /**
    @notice
    The first owner of each token ID, stored on first transfer out.

    _nft The NFT contract to which the token belongs.
    _tokenId The ID of the token to get the stored first owner of.
  */
  mapping(address => mapping(uint256 => address)) public override firstOwnerOf;

  /**
    @notice
    The common base for the tokenUri's

    _nft The NFT for which the base URI applies.
  */
  mapping(address => string) public override baseUriOf;

  /**
    @notice
    Custom token URI resolver, superceeds base URI.

    _nft The NFT for which the token URI resolver applies.
  */
  mapping(address => IJBTokenUriResolver) public override tokenUriResolverOf;

  /**
    @notice
    Contract metadata uri.

    _nft The NFT for which the contract URI resolver applies.
  */
  mapping(address => string) public override contractUriOf;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    Gets an array of all the active tiers. 

    @param _nft The NFT contract to get tiers for.

    @return _tiers All the tiers.
  */
  function tiers(address _nft) external view override returns (JBNFTRewardTier[] memory _tiers) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers[_nft];

    // Initialize an array with the appropriate length.
    _tiers = new JBNFTRewardTier[](_numberOfTiers);

    // Count the number of active tiers
    uint256 _activeTiers;

    // Loop through each tier.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Add the tier to the array if it hasn't been removed (tiers are unsorted)
      if (!isTierRemoved[_nft][_i]) {
        unchecked {
          // Get a reference to the tier data (1-indexed). Overwrite empty tiers.
          _tiers[_activeTiers++] = JBNFTRewardTier({id: _i, data: tierData[_nft][_i]});
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

    @param _nft The NFT to get a tier within.
    @param _id The ID of the tier to get. 

    @return The tier.
  */
  function tier(address _nft, uint256 _id) external view override returns (JBNFTRewardTier memory) {
    return JBNFTRewardTier({id: _id, data: tierData[_nft][_id]});
  }

  /** 
  
    @notice
    Return the tier for the specified token ID. 

    @param _nft The NFT to get a tier within.
    @param _tokenId The ID of token to return the tier of. 

    @return The tier.
  */
  function tierOfTokenId(address _nft, uint256 _tokenId)
    external
    view
    override
    returns (JBNFTRewardTier memory)
  {
    // Get a reference to the tier's ID.
    uint256 _tierId = tierIdOfToken(_tokenId);

    return JBNFTRewardTier({id: _tierId, data: tierData[_nft][_tierId]});
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @param _nft The NFT to get a total supply of.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply(address _nft) external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData storage _data;

    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers[_nft];

    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Set the tier being iterated on.
      _data = tierData[_nft][_i];

      // Increment the total supply with the amount used already.
      supply += _data.initialQuantity - _data.remainingQuantity;

      unchecked {
        --_i;
      }
    }
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _nft The NFT to get a number of reserved tokens outstanding.
    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.

    @return The outstanding number of reserved tokens within the tier.
  */
  function numberOfReservedTokensOutstandingFor(address _nft, uint256 _tierId)
    external
    view
    override
    returns (uint256)
  {
    return _numberOfReservedTokensOutstandingFor(_nft, _tierId, tierData[_nft][_tierId]);
  }

  /** 
    @notice 
    The total number of tokens owned by the given owner. 

    @param _nft The NFT to get a balance from.
    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner accross all tiers.
  */
  function balanceOf(address _nft, address _owner) public view override returns (uint256 balance) {
    // Keep a reference to the number of tiers in stack.
    uint256 _numberOfTiers = numberOfTiers[_nft];

    // Loop through all tiers.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      balance += tierBalanceOf[_nft][_owner][_i];

      unchecked {
        --_i;
      }
    }
  }

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _nft The NFT to get voting units within.
    @param _account The account to get voting units for.

    @return units The voting units for the account.
  */
  function votingUnitsOf(address _nft, address _account)
    external
    view
    virtual
    override
    returns (uint256 units)
  {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers[_nft];

    // Keep a reference to the balance being iterated on.
    uint256 _balance;

    // Loop through all tiers.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      _balance = tierBalanceOf[_nft][_account][_i];

      if (_balance != 0)
        // Add the tier's voting units.
        units += _balance * tierData[_nft][_i].votingUnits;

      unchecked {
        --_i;
      }
    }
  }

  /**
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `totalRedemptionWeight`.

    @param _nft The NFT for which the redemption weight is being calculated.
    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return weight The weight.
  */
  function redemptionWeightOf(address _nft, uint256[] calldata _tokenIds)
    public
    view
    override
    returns (uint256 weight)
  {
    // Get a reference to the total number of tokens.
    uint256 _numberOfTokenIds = _tokenIds.length;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _numberOfTokenIds; ) {
      weight += uint256(tierData[_nft][tierIdOfToken(_tokenIds[_i])].contributionFloor);

      unchecked {
        ++_i;
      }
    }
  }

  /**
    @notice
    The cumulative weight that all token IDs have in redemptions.

    @param _nft The NFT for which the redemption weight is being calculated.

    @return weight The total weight.
  */
  function totalRedemptionWeight(address _nft) public view override returns (uint256 weight) {
    // Get a reference to the total number of tiers.
    uint256 _numberOfTiers = numberOfTiers[_nft];

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _numberOfTiers; ) {
      _data = tierData[_nft][_i + 1];

      // Add the tier's contribution floor multiplied by the quantity minted.
      weight +=
        (uint256(_data.contributionFloor) * (_data.initialQuantity - _data.remainingQuantity)) +
        _numberOfReservedTokensOutstandingFor(_nft, _i, _data);

      unchecked {
        ++_i;
      }
    }
  }

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

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Adds tiers. 

    @param _tierData The tiers to add.
    @param _constructorTiers A flag indicating if tiers with voting units and reserved rate should be allowed.

    @return tierIds The IDs of the tiers added.
  */
  function recordAddTierData(JBNFTRewardTierData[] memory _tierData, bool _constructorTiers)
    external
    override
    returns (uint256[] memory tierIds)
  {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Get a reference to the number of new tiers.
    uint256 _numberOfNewTiers = _tierData.length;

    // Get a reference to the current total number of tiers.
    uint256 _currentNumberOfTiers = numberOfTiers[msg.sender];

    // Initialize an array with the appropriate length.
    tierIds = new uint256[](_numberOfNewTiers);

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
      tierData[msg.sender][_tierId] = _data;

      // Set the tier ID in the returned value.
      tierIds[_numberOfNewTiers - _i] = _tierId;

      unchecked {
        --_i;
      }
    }

    numberOfTiers[msg.sender] = _currentNumberOfTiers + _numberOfNewTiers;
  }

  /** 
    @notice
    Mint a token within the tier for the provided value.

    @dev
    Only a project owner can mint tokens.

    @param _tierId The ID of the tier to mint within.
    @param _count The number of reserved tokens to mint. 

    @return tokenIds The IDs of the tokens being minted as reserves.
  */
  function recordMintReservesFor(uint256 _tierId, uint256 _count)
    external
    override
    returns (uint256[] memory tokenIds)
  {
    // Get a reference to the tier.
    JBNFTRewardTierData storage _data = tierData[msg.sender][_tierId];

    // Get a reference to the number of reserved tokens mintable for the tier.
    uint256 _numberOfReservedTokensOutstanding = _numberOfReservedTokensOutstandingFor(
      msg.sender,
      _tierId,
      _data
    );

    // Can't mint more reserves than expected.
    if (_count > _numberOfReservedTokensOutstanding) revert INSUFFICIENT_RESERVES();

    // Increment the number of reserved tokens minted.
    numberOfReservesMintedFor[msg.sender][_tierId] += _count;

    // Initialize an array with the appropriate length.
    tokenIds = new uint256[](_count);

    for (uint256 _i; _i < _count; ) {
      // Generate the tokens.
      tokenIds[_i] = _generateTokenId(_tierId, _data.initialQuantity - --_data.remainingQuantity);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Sets the reserved token beneficiary.

    @param _beneficiary The reservd token beneficiary.
  */
  function recordSetReservedTokenBeneficiary(address _beneficiary) external override {
    reservedTokenBeneficiary[msg.sender] = _beneficiary;
  }

  /** 
    @notice
    Record a token transfer

    @param _tierId The ID the tier being transfered
    @param _from The sender of the token
    @param _to The recipient of the token
  */
  function recordTransferForTier(
    uint256 _tierId,
    address _from,
    address _to
  ) external override {
    // If this is not a mint then subtract the tier balance from the original holder.
    if (_from != address(0))
      // decrease the tier balance for the sender
      --tierBalanceOf[msg.sender][_from][_tierId];

    // if this is a burn the balance is not added
    if (_to != address(0)) {
      unchecked {
        // increase the tier balance for the beneficiary
        ++tierBalanceOf[msg.sender][_to][_tierId];
      }
    }
  }

  /** 
    @notice
    Remove tiers. 

    @param _tierIds The tiers IDs to remove.
  */
  function recordRemoveTierIds(uint256[] calldata _tierIds) external override {
    // Get a reference to the number of tiers being removed.
    uint256 _numTiers = _tierIds.length;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on, 0-indexed
      _tierId = _tierIds[_i];

      // If the tier is locked throw an error.
      if (tierData[msg.sender][_tierId].lockedUntil >= block.timestamp) revert TIER_LOCKED();

      // Set the tier as removed.
      isTierRemoved[msg.sender][_tierId] = true;

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Mints a token in the best available tier.

    @param _amount The amount to base the mint on.
    @param _expectMint A flag indicating if a mint is expected.

    @return tokenId The token ID minted.
    @return tierId The ID of the tier minted from.
    @return leftoverAmount The amount leftover after the mint. 
  */
  function recordMintBestAvailableTier(uint256 _amount, bool _expectMint)
    external
    override
    returns (
      uint256 tokenId,
      uint256 tierId,
      uint256 leftoverAmount
    )
  {
    // Keep a reference to the number of tiers.
    uint256 _numberOfTiers = numberOfTiers[msg.sender];

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData memory _data;

    // Keep a reference to the best contribution floor.
    uint256 _bestContributioFloor;

    // Loop through each tier and keep track of the best option.
    for (uint256 _i = _numberOfTiers; _i != 0; ) {
      if (!isTierRemoved[msg.sender][_i]) {
        // Set the tier being iterated on. Tier's are 1 indexed.
        _data = tierData[msg.sender][_i];

        // Mint if the contribution value is at least as much as the floor, there's sufficient supply, and the floor is better than the best tier.
        if (
          _data.contributionFloor > _bestContributioFloor &&
          _data.contributionFloor <= _amount &&
          (_data.remainingQuantity -
            _numberOfReservedTokensOutstandingFor(msg.sender, _i, _data)) !=
          0
        ) {
          _bestContributioFloor = _data.contributionFloor;
          tierId = _i;
        }
      }

      unchecked {
        --_i;
      }
    }

    // Keep a reference to the best tier.
    JBNFTRewardTierData storage _bestTierData = tierData[msg.sender][tierId];

    // Make the token ID.
    unchecked {
      // Keep a reference to the token ID.
      tokenId = _generateTokenId(
        tierId,
        _bestTierData.initialQuantity - --_bestTierData.remainingQuantity
      );
    }

    // If there's no best tier, return.
    if (tokenId == 0) {
      // Make sure a mint was not expected.
      if (_expectMint) revert NOT_AVAILABLE();
      leftoverAmount = _amount;
    } else {
      // Set the leftover amount.
      leftoverAmount = _amount - _bestContributioFloor;
    }
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _tierIds The IDs of the tier to mint from.

    @return tokenIds The IDs of the tokens minted.
    @return leftoverAmount The amount leftover after the mint.
  */
  function recordMint(uint256 _amount, uint8[] calldata _tierIds)
    external
    override
    returns (uint256[] memory tokenIds, uint256 leftoverAmount)
  {
    // Set the leftover amount as the initial amount.
    leftoverAmount = _amount;

    // Get a reference to the number of tiers.
    uint256 _numberOfTiers = _tierIds.length;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTierData storage _data;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    // Initialize an array with the appropriate length.
    tokenIds = new uint256[](_numberOfTiers);

    for (uint256 _i; _i < _numberOfTiers; ) {
      // Set the tier ID being iterated on.
      _tierId = _tierIds[_i];

      // Make sure the tier hasn't been removed.
      if (isTierRemoved[msg.sender][_tierId]) revert TIER_REMOVED();

      // Keep a reference to the tier being iterated on.
      _data = tierData[msg.sender][_tierId];

      // Make sure the provided tier exists.
      if (_data.initialQuantity == 0) revert INVALID_TIER();

      // Make sure the amount meets the tier's contribution floor.
      if (_data.contributionFloor > leftoverAmount) revert INSUFFICIENT_AMOUNT();

      // Make sure there are enough units available.
      if (
        _data.remainingQuantity -
          _numberOfReservedTokensOutstandingFor(msg.sender, _tierId, _data) ==
        0
      ) revert OUT();

      // Mint the tokens.
      unchecked {
        // Keep a reference to the token ID.
        tokenIds[_i] = _generateTokenId(_tierId, _data.initialQuantity - --_data.remainingQuantity);
      }

      // Update the leftover amount;
      leftoverAmount = leftoverAmount - _data.contributionFloor;

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Sets the first owner of a token.

    @param _tokenId The ID of the token having the first owner set.
    @param _owner The owner to set as the first owner.
  */
  function recordSetFirstOwnerOf(uint256 _tokenId, address _owner) external override {
    firstOwnerOf[msg.sender][_tokenId] = _owner;
  }

  /** 
    @notice
    Sets the base URI. 

    @param _uri The base URI to set.
  */
  function recordSetBaseUri(string calldata _uri) external override {
    baseUriOf[msg.sender] = _uri;
  }

  /** 
    @notice
    Sets the contract URI. 

    @param _uri The contract URI to set.
  */
  function recordSetContractUri(string calldata _uri) external override {
    contractUriOf[msg.sender] = _uri;
  }

  /** 
    @notice
    Sets the token URI resolver. 

    @param _resolver The resolver to set.
  */
  function recordSetTokenUriResolver(IJBTokenUriResolver _resolver) external override {
    tokenUriResolverOf[msg.sender] = _resolver;
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _nft The NFT to get reserved tokens outstanding.
    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.
    @param _data The tier data to get a number of reserved tokens outstanding.

    @return numberReservedTokensOutstanding The outstanding number of reserved tokens within the tier.
  */
  function _numberOfReservedTokensOutstandingFor(
    address _nft,
    uint256 _tierId,
    JBNFTRewardTierData memory _data
  ) internal view returns (uint256) {
    // Invalid tier or no reserved rate?
    if (_data.initialQuantity == 0 || _data.reservedRate == 0) return 0;

    // No token minted yet? Round up to 1
    if (_data.initialQuantity == _data.remainingQuantity) return 1;

    // The number of reserved token of the tier already minted
    uint256 reserveTokensMinted = numberOfReservesMintedFor[_nft][_tierId];

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
}
