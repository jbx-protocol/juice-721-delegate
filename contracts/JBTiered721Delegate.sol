// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBFundingCycleMetadataResolver.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './abstract/JB721Delegate.sol';
import './abstract/Votes.sol';
import './interfaces/IJBTiered721Delegate.sol';
import './libraries/JBIpfsDecoder.sol';
import './libraries/JBTiered721FundingCycleMetadataResolver.sol';
import './structs/JBTiered721Flags.sol';
import './structs/JB721PricingParams.sol';

/**
  @title
  JBTiered721Delegate

  @notice
  Delegate that offers project contributors NFTs with tiered price floors upon payment and the ability to redeem NFTs for treasury assets based based on price floor.

  @dev
  Adheres to -
  IJBTiered721Delegate: General interface for the methods in this contract that interact with the blockchain's state according to the protocol's rules.

  @dev
  Inherits from -
  JB721Delegate: A generic NFT delegate.
  Votes: A helper for voting balance snapshots.
  Ownable: Includes convenience functionality for checking a message sender's permissions before executing certain transactions.
*/
contract JBTiered721Delegate is IJBTiered721Delegate, JB721Delegate, Votes, Ownable {
  using Checkpoints for Checkpoints.History;

  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error NOT_AVAILABLE();
  error OVERSPENDING();
  error PRICING_RESOLVER_CHANGES_LCOKED();
  error RESERVED_TOKEN_MINTING_PAUSED();
  error TRANSFERS_PAUSED();

  mapping(address => mapping(uint256 => address)) private _tierDelegation;
  mapping(address => mapping(uint256 => Checkpoints.History)) private _delegateTierCheckpoints;
  mapping(uint256 => Checkpoints.History) private _totalTierCheckpoints;

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /**
    @notice
    The contract that stores and manages the NFT's data.
  */
  IJBTiered721DelegateStore public immutable override store;

  /**
    @notice
    The contract storing all funding cycle configurations.
  */
  IJBFundingCycleStore public immutable override fundingCycleStore;

  /**
    @notice
    The contract that exposes price feeds.
  */
  IJBPrices public immutable override prices;

  /** 
    @notice
    The currency that is accepted when minting tier NFTs. 
  */
  uint256 public immutable override pricingCurrency;

  /** 
    @notice
    The currency that is accepted when minting tier NFTs. 
  */
  uint256 public immutable override pricingDecimals;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice
    The amount that each address has paid that has not yet contribute to the minting of an NFT. 

    _address The address to which the credits belong.
  */
  mapping(address => uint256) public override creditsOf;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The total number of tokens owned by the given owner across all tiers. 

    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner accross all tiers.
  */
  function balanceOf(address _owner) public view override returns (uint256 balance) {
    return store.balanceOf(address(this), _owner);
  }

  /**
    @notice
    The first owner of each token ID, which corresponds to the address that originally contributed to the project to receive the NFT.

    @param _tokenId The ID of the token to get the first owner of.

    @return The first owner of the token.
  */
  function firstOwnerOf(uint256 _tokenId) external view override returns (address) {
    // Get a reference to the first owner.
    address _storedFirstOwner = store.firstOwnerOf(address(this), _tokenId);

    // If the stored first owner is set, return it.
    if (_storedFirstOwner != address(0)) return _storedFirstOwner;

    // Otherwise, the first owner must be the current owner.
    return _owners[_tokenId];
  }

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The metadata URI of the provided token ID.

    @dev
    Defer to the tokenUriResolver if set, otherwise, use the tokenUri set with the token's tier.

    @param _tokenId The ID of the token to get the tier URI for. 

    @return The token URI corresponding with the tier or the tokenUriResolver URI.
  */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    // A token without an owner doesn't have a URI.
    if (_owners[_tokenId] == address(0)) return '';

    // Get a reference to the URI resolver.
    IJBTokenUriResolver _resolver = store.tokenUriResolverOf(address(this));

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(_resolver) != address(0)) return _resolver.getUri(_tokenId);

    // Return the token URI for the token's tier.
    return
      JBIpfsDecoder.decode(
        store.baseUriOf(address(this)),
        store.encodedTierIPFSUriOf(address(this), _tokenId)
      );
  }

  /** 
    @notice
    Returns the URI where contract metadata can be found. 

    @return The contract's metadata URI.
  */
  function contractURI() external view override returns (string memory) {
    return store.contractUriOf(address(this));
  }

  /**
    @notice
    Returns the delegate of an account for specific tier.

    @param _account The account to check for a delegate of.
    @param _tier the tier to check within.
  */
  function getTierDelegate(address _account, uint256 _tier)
    external
    view
    override
    returns (address)
  {
    return _tierDelegation[_account][_tier];
  }

  /**
    @notice
    Returns the current voting power of an address for a specific tier.

    @param _account The address to check.
    @param _tier The tier to check within.
  */
  function getTierVotes(address _account, uint256 _tier) external view override returns (uint256) {
    return _delegateTierCheckpoints[_account][_tier].latest();
  }

  /**
    @notice
    Returns the past voting power of a specific address for a specific tier.

    @param _account The address to check.
    @param _tier The tier to check within.
    @param _blockNumber the blocknumber to check the voting power at.
  */
  function getPastTierVotes(
    address _account,
    uint256 _tier,
    uint256 _blockNumber
  ) external view override returns (uint256) {
    return _delegateTierCheckpoints[_account][_tier].getAtBlock(_blockNumber);
  }

  /**
    @notice
    Returns the total amount of voting power that exists for a tier.

    @param _tier The tier to check.
  */
  function getTierTotalVotes(uint256 _tier) external view override returns (uint256) {
    return _totalTierCheckpoints[_tier].latest();
  }

  /**
    @notice
    Returns the total amount of voting power that exists for a tier.

    @param _tier The tier to check.
    @param _blockNumber The blocknumber to check the total voting power at.
  */
  function getPastTierTotalVotes(uint256 _tier, uint256 _blockNumber)
    external
    view
    override
    returns (uint256)
  {
    if (_blockNumber >= block.number) revert BLOCK_NOT_YET_MINED();
    return _totalTierCheckpoints[_tier].getAtBlock(_blockNumber);
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
      _interfaceId == type(IJBTiered721Delegate).interfaceId ||
      super.supportsInterface(_interfaceId);
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projectId The ID of the project this contract's functionality applies to.
    @param _directory The directory of terminals and controllers for projects.
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _fundingCycleStore A contract storing all funding cycle configurations.
    @param _baseUri A URI to use as a base for full token URIs.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _pricing The tier pricing according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _store A contract that stores the NFT's data.
    @param _flags A set of flags that help define how this contract works.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBFundingCycleStore _fundingCycleStore,
    string memory _baseUri,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    JB721PricingParams memory _pricing,
    IJBTiered721DelegateStore _store,
    JBTiered721Flags memory _flags
  ) JB721Delegate(_projectId, _directory, _name, _symbol) EIP712(_name, '1') {
    fundingCycleStore = _fundingCycleStore;
    store = _store;
    pricingCurrency = _pricing.currency;
    pricingDecimals = _pricing.decimals;
    prices = _pricing.prices;

    // Store the base URI if provided.
    if (bytes(_baseUri).length != 0) _store.recordSetBaseUri(_baseUri);

    // Set the contract URI if provided.
    if (bytes(_contractUri).length != 0) _store.recordSetContractUri(_contractUri);

    // Set the token URI resolver if provided.
    if (_tokenUriResolver != IJBTokenUriResolver(address(0)))
      _store.recordSetTokenUriResolver(_tokenUriResolver);

    // Set the pricing resolver if provided.
    if (_pricing.resolver != IJB721PricingResolver(address(0)))
      _store.recordSetPricingResolver(_pricing.resolver);

    // Record adding the provided tiers.
    if (_pricing.tiers.length > 0) _store.recordAddTiers(_pricing.tiers);

    // Set the locked reserved token change preference if needed.
    if (_flags.lockReservedTokenChanges)
      _store.recordLockReservedTokenChanges(_flags.lockReservedTokenChanges);

    // Set the locked voting unit change preference if needed.
    if (_flags.lockVotingUnitChanges)
      _store.recordLockVotingUnitChanges(_flags.lockVotingUnitChanges);

    // Set the locked pricing resolver change preference if needed.
    if (_flags.lockPricingResolverChanges)
      _store.recordLockPricingResolverChanges(_flags.lockPricingResolverChanges);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mint reserved tokens within the tier for the provided value.

    @param _mintReservesForTiersData Contains information about how many reserved tokens to mint for each tier.
  */
  function mintReservesFor(JBTiered721MintReservesForTiersData[] memory _mintReservesForTiersData)
    external
    override
  {
    // Keep a reference to the number of tiers there are to mint reserved for.
    uint256 _numberOfTiers = _mintReservesForTiersData.length;

    for (uint256 _i; _i < _numberOfTiers; ) {
      // Get a reference to the data being iterated on.
      JBTiered721MintReservesForTiersData memory _data = _mintReservesForTiersData[_i];

      // Mint for the tier.
      mintReservesFor(_data.tierId, _data.count);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Adjust the tiers mintable through this contract, adhering to any locked tier constraints. 

    @dev
    Only the contract's owner can adjust the tiers.

    @param _tiersToAdd An array of tier data to add.
    @param _tierIdsToRemove An array of tier IDs to remove.
  */
  function adjustTiers(JB721TierParams[] calldata _tiersToAdd, uint256[] calldata _tierIdsToRemove)
    external
    override
    onlyOwner
  {
    // Get a reference to the number of tiers being added.
    uint256 _numberOfTiersToAdd = _tiersToAdd.length;

    // Add the tiers.
    if (_numberOfTiersToAdd != 0) {
      // Record the added tiers in the store.
      uint256[] memory _tierIdsAdded = store.recordAddTiers(_tiersToAdd);

      // Emit events for each added tier.
      for (uint256 _i; _i < _numberOfTiersToAdd; ) {
        emit AddTier(_tierIdsAdded[_i], _tiersToAdd[_i], msg.sender);
        unchecked {
          ++_i;
        }
      }
    }

    // Get a reference to the number of tiers being removed.
    uint256 _numberOfTiersToRemove = _tierIdsToRemove.length;

    // Remove the tiers.
    if (_numberOfTiersToRemove != 0) {
      // Record the removed tiers.
      store.recordRemoveTierIds(_tierIdsToRemove);

      // Emit events for each removed tier.
      for (uint256 _i; _i < _numberOfTiersToRemove; ) {
        emit RemoveTier(_tierIdsToRemove[_i], msg.sender);
        unchecked {
          ++_i;
        }
      }
    }
  }

  /** 
    @notice
    Sets the beneificiary of the reserved tokens for tiers where a specific beneficiary isn't set. 

    @dev
    Only the contract's owner can set the default reserved token beneficiary.

    @param _beneficiary The default beneificiary of the reserved tokens.
  */
  function setDefaultReservedTokenBeneficiary(address _beneficiary) external override onlyOwner {
    // Set the beneficiary.
    store.recordSetDefaultReservedTokenBeneficiary(_beneficiary);

    emit SetDefaultReservedTokenBeneficiary(_beneficiary, msg.sender);
  }

  /**
    @notice
    Set a base token URI.

    @dev
    Only the contract's owner can set the base URI.

    @param _baseUri The new base URI.
  */
  function setBaseUri(string memory _baseUri) external override onlyOwner {
    // Store the new value.
    store.recordSetBaseUri(_baseUri);

    emit SetBaseUri(_baseUri, msg.sender);
  }

  /**
    @notice
    Set a contract metadata URI to contain opensea-style metadata.

    @dev
    Only the contract's owner can set the contract URI.

    @param _contractUri The new contract URI.
  */
  function setContractUri(string calldata _contractUri) external override onlyOwner {
    // Store the new value.
    store.recordSetContractUri(_contractUri);

    emit SetContractUri(_contractUri, msg.sender);
  }

  /**
    @notice
    Set a token URI resolver.

    @dev
    Only the contract's owner can set the token URI resolver.

    @param _tokenUriResolver The new URI resolver.
  */
  function setTokenUriResolver(IJBTokenUriResolver _tokenUriResolver) external override onlyOwner {
    // Store the new value.
    store.recordSetTokenUriResolver(_tokenUriResolver);

    emit SetTokenUriResolver(_tokenUriResolver, msg.sender);
  }

  /**
    @notice
    Set a price resolver.

    @dev
    Only the contract's owner can set the pricing resolver.

    @param _pricingResolver The new pricing resolver.
  */
  function setPricingResolver(IJB721PricingResolver _pricingResolver) external override onlyOwner {
    // Make sure pricing resolver changes aren't locked.
    if (store.lockPricingResolverChangesFor(address(this)))
      revert PRICING_RESOLVER_CHANGES_LCOKED();

    // Store the new value.
    store.recordSetPricingResolver(_pricingResolver);

    emit SetPricingResolver(_pricingResolver, msg.sender);
  }

  //*********************************************************************//
  // ----------------------- public transactions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mint reserved tokens within the tier for the provided value.

    @param _tierId The ID of the tier to mint within.
    @param _count The number of reserved tokens to mint. 
  */
  function mintReservesFor(uint256 _tierId, uint256 _count) public override {
    // Get a reference to the project's current funding cycle.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(projectId);

    // Minting reserves must not be paused.
    if (
      JBTiered721FundingCycleMetadataResolver.mintingReservesPaused(
        (JBFundingCycleMetadataResolver.metadata(_fundingCycle))
      )
    ) revert RESERVED_TOKEN_MINTING_PAUSED();

    // Record the minted reserves for the tier.
    uint256[] memory _tokenIds = store.recordMintReservesFor(_tierId, _count);

    // Keep a reference to the reserved token beneficiary.
    address _reservedTokenBeneficiary = store.reservedTokenBeneficiaryOf(address(this), _tierId);

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    for (uint256 _i; _i < _count; ) {
      // Set the token ID.
      _tokenId = _tokenIds[_i];

      // Mint the token.
      _mint(_reservedTokenBeneficiary, _tokenId);

      emit MintReservedToken(_tokenId, _tierId, _reservedTokenBeneficiary, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /**
    @notice 
    Delegates votes from the sender to `delegatee`.

    @param _delegatee The account to delegate tier voting units to.
    @param _tierId The ID of the tier to delegate voting units for.
   */
  function setTierDelegate(address _delegatee, uint256 _tierId) public virtual override {
    _delegateTier(msg.sender, _delegatee, _tierId);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /**
    @notice
    Mints for a given contribution to the beneficiary.

    @param _data The Juicebox standard project contribution data.
  */
  function _processPayment(JBDidPayData calldata _data) internal override {
    // Normalize the currency.
    uint256 _value;
    if (_data.amount.currency == pricingCurrency) _value = _data.amount.value;
    else if (prices != IJBPrices(address(0)))
      _value = PRBMath.mulDiv(
        _data.amount.value,
        10**pricingDecimals,
        prices.priceFor(_data.amount.currency, pricingCurrency, _data.amount.decimals)
      );
    else return;

    // Keep a reference to the amount of credits the beneficiary already has.
    uint256 _credits = creditsOf[_data.beneficiary];

    // Set the leftover amount as the initial value, including any credits the beneficiary might already have.
    uint256 _leftoverAmount = _value + _credits;

    // Keep a reference to a flag indicating if a mint is expected from discretionary funds. Defaults to false, meaning to mint is expected.
    bool _expectMintFromExtraFunds;

    // Keep a reference to the flag indicating if the transaction should revert if all provded funds aren't spent. Defaults to false, meaning only a minimum payment is enforced.
    bool _dontOverspend;

    // Skip the first 32 bytes which are used by the JB protocol to pass the paying project's ID when paying from a JBSplit.
    // Check the 4 bytes interfaceId to verify the metadata is intended for this contract.
    if (
      _data.metadata.length > 36 &&
      bytes4(_data.metadata[32:36]) == type(IJB721Delegate).interfaceId
    ) {
      // Keep a reference to the flag indicating if the transaction should not mint anything.
      bool _dontMint;

      // Keep a reference to the the specific tier IDs to mint.
      uint16[] memory _tierIdsToMint;

      // Decode the metadata.
      (, , _dontMint, _expectMintFromExtraFunds, _dontOverspend, _tierIdsToMint) = abi.decode(
        _data.metadata,
        (bytes32, bytes4, bool, bool, bool, uint16[])
      );

      // Don't mint if not desired.
      if (_dontMint) return;

      // Mint rewards if they were specified.
      if (_tierIdsToMint.length != 0)
        _leftoverAmount = _mintAll(
          _leftoverAmount,
          _data.amount.currency,
          _tierIdsToMint,
          _data.beneficiary
        );
    }

    // If there are funds leftover, mint the best available with it.
    if (_leftoverAmount != 0) {
      _leftoverAmount = _mintBestAvailableTier(
        _leftoverAmount,
        _data.amount.currency,
        _data.beneficiary,
        _expectMintFromExtraFunds
      );

      if (_leftoverAmount != 0) {
        // Make sure there are no leftover funds after minting if not expected.
        if (_dontOverspend) revert OVERSPENDING();

        // Increment the leftover amount.
        creditsOf[_data.beneficiary] = _leftoverAmount;
      } else if (_credits != 0) creditsOf[_data.beneficiary] = 0;
    } else if (_credits != 0) creditsOf[_data.beneficiary] = 0;
  }

  /** 
    @notice
    A function that will run when a tokens are burned via redemption.

    @param _tokenIds The IDs of the tokens that were burned.
  */
  function _didBurn(uint256[] memory _tokenIds) internal override {
    // Add to burned counter.
    store.recordBurn(_tokenIds);
  }

  /** 
    @notice
    Mints a token in the best available tier.

    @param _amount The amount to base the mint on.
    @param _currency The currency being paid in.
    @param _beneficiary The address to mint for.
    @param _expectMint A flag indicating if a mint was expected.

    @return  leftoverAmount The amount leftover after the mint.
  */
  function _mintBestAvailableTier(
    uint256 _amount,
    uint256 _currency,
    address _beneficiary,
    bool _expectMint
  ) internal returns (uint256 leftoverAmount) {
    // Keep a reference to the token ID.
    uint256 _tokenId;

    // Keep a reference to the tier ID.
    uint256 _tierId;

    // Record the mint.
    (_tokenId, _tierId, leftoverAmount) = store.recordMintBestAvailableTier(
      _amount,
      _beneficiary,
      _currency
    );

    // If there's no best tier, return or revert.
    if (_tokenId == 0) {
      // Make sure a mint was not expected.
      if (_expectMint) revert NOT_AVAILABLE();
      return leftoverAmount;
    }

    // Mint the tokens.
    _mint(_beneficiary, _tokenId);

    emit Mint(_tokenId, _tierId, _beneficiary, _amount - leftoverAmount, msg.sender);
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _currency The currency being paid in.
    @param _mintTierIds An array of tier IDs that are intended to be minted.
    @param _beneficiary The address to mint for.

    @return leftoverAmount The amount leftover after the mint.
  */
  function _mintAll(
    uint256 _amount,
    uint256 _currency,
    uint16[] memory _mintTierIds,
    address _beneficiary
  ) internal returns (uint256 leftoverAmount) {
    // Keep a reference to the token ID.
    uint256[] memory _tokenIds;

    // Record the mint. The returned token IDs correspond to the tiers passed in.
    (_tokenIds, leftoverAmount) = store.recordMint(_amount, _mintTierIds, _beneficiary, _currency);

    // Get a reference to the number of mints.
    uint256 _mintsLength = _tokenIds.length;

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    // Loop through each token ID and mint.
    for (uint256 _i; _i < _mintsLength; ) {
      // Get a reference to the tier being iterated on.
      _tokenId = _tokenIds[_i];

      // Mint the tokens.
      _mint(_beneficiary, _tokenId);

      emit Mint(_tokenId, _mintTierIds[_i], _beneficiary, _amount, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `_totalRedemptionWeight`. 

    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return The weight.
  */
  function _redemptionWeightOf(uint256[] memory _tokenIds)
    internal
    view
    virtual
    override
    returns (uint256)
  {
    return store.redemptionWeightOf(address(this), _tokenIds);
  }

  /** 
    @notice
    The cumulative weight that all token IDs have in redemptions. 

    @return The total weight.
  */
  function _totalRedemptionWeight() internal view virtual override returns (uint256) {
    return store.totalRedemptionWeight(address(this));
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
    return store.votingUnitsOf(address(this), _account);
  }

  function _getTierVotingUnits(address _account, uint256 _tierId)
    internal
    view
    virtual
    returns (uint256 units)
  {
    return store.tierVotingUnitsOf(address(this), _account, _tierId);
  }

  /**
    @notice
    User the hook to register the first owner if it's not yet regitered.

    @param _from The address where the transfer is originating.
    @param _to The address to which the transfer is being made.
    @param _tokenId The ID of the token being transfered.
  */
  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal virtual override {
    // Get a reference to the project's current funding cycle.
    JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(projectId);

    // Transfered must not be paused.
    if (
      JBTiered721FundingCycleMetadataResolver.transfersPaused(
        (JBFundingCycleMetadataResolver.metadata(_fundingCycle))
      )
    ) revert TRANSFERS_PAUSED();

    // If there's no stored first owner, and the transfer isn't originating from the zero address as expected for mints, store the first owner.
    if (_from != address(0) && store.firstOwnerOf(address(this), _tokenId) == address(0))
      store.recordSetFirstOwnerOf(_tokenId, _from);

    super._beforeTokenTransfer(_from, _to, _tokenId);
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
    JB721Tier memory _tier = store.tierOfTokenId(address(this), _tokenId);

    // Record the transfer.
    store.recordTransferForTier(_tier.id, _from, _to);

    if (_tier.votingUnits != 0) {
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _tier.votingUnits);
      _transferTierVotingUnits(_from, _to, _tier.id, _tier.votingUnits);
    }

    super._afterTokenTransfer(_from, _to, _tokenId);
  }

  /**
    @notice 
    Delegate all of `account`'s voting units for the specified tier to `delegatee`.

    @param _account The account delegating tier voting units.
    @param _delegatee The account to delegate tier voting units to.
    @param _tierId The ID of the tier for which voting units are being transfered.
   */
  function _delegateTier(
    address _account,
    address _delegatee,
    uint256 _tierId
  ) internal virtual {
    // Get the current delegatee
    address _oldDelegate = _tierDelegation[_account][_tierId];

    // Store the new delegatee
    _tierDelegation[_account][_tierId] = _delegatee;

    emit DelegateChanged(_account, _oldDelegate, _delegatee);

    // Move the votes.
    _moveTierDelegateVotes(
      _oldDelegate,
      _delegatee,
      _tierId,
      _getTierVotingUnits(_account, _tierId)
    );
  }

  /**
    @notice 
    Transfers, mints, or burns tier voting units. To register a mint, `from` should be zero. To register a burn, `to` should be zero. Total supply of voting units will be adjusted with mints and burns.

    @param _from The account to transfer tier voting units from.
    @param _to The account to transfer tier voting units to.
    @param _tierId The ID of the tier for which voting units are being transfered.
    @param _amount The amount of voting units to delegate.
   */
  function _transferTierVotingUnits(
    address _from,
    address _to,
    uint256 _tierId,
    uint256 _amount
  ) internal virtual {
    // If minting, add to the total tier checkpoints.
    if (_from == address(0)) _totalTierCheckpoints[_tierId].push(_add, _amount);

    // If burning, subtract from the total tier checkpoints.
    if (_to == address(0)) _totalTierCheckpoints[_tierId].push(_subtract, _amount);

    // Move delegated votes.
    _moveTierDelegateVotes(
      _tierDelegation[_from][_tierId],
      _tierDelegation[_to][_tierId],
      _tierId,
      _amount
    );
  }

  /**
    @notice 
    Moves delegated tier votes from one delegate to another.

    @param _from The account to transfer tier voting units from.
    @param _to The account to transfer tier voting units to.
    @param _tierId The ID of the tier for which voting units are being transfered.
    @param _amount The amount of voting units to delegate.
  */
  function _moveTierDelegateVotes(
    address _from,
    address _to,
    uint256 _tierId,
    uint256 _amount
  ) private {
    // Nothing to do if moving to the same account, or no amount is being moved.
    if (_from == _to || _amount == 0) return;

    // If not moving from the zero address, update the checkpoints to subtract the amount.
    if (_from != address(0)) {
      (uint256 _oldValue, uint256 _newValue) = _delegateTierCheckpoints[_from][_tierId].push(
        _subtract,
        _amount
      );
      emit TierDelegateVotesChanged(_from, _oldValue, _newValue, _tierId, msg.sender);
    }

    // If not moving to the zero address, update the checkpoints to add the amount.
    if (_to != address(0)) {
      (uint256 _oldValue, uint256 _newValue) = _delegateTierCheckpoints[_to][_tierId].push(
        _add,
        _amount
      );
      emit TierDelegateVotesChanged(_to, _tierId, _oldValue, _newValue, msg.sender);
    }
  }
}
