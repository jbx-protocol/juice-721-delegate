// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBFundingCycleMetadataResolver.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './abstract/JB721Delegate.sol';
import './interfaces/IJBTiered721Delegate.sol';
import './libraries/JBIpfsDecoder.sol';
import './libraries/JBTiered721FundingCycleMetadataResolver.sol';
import './structs/JBTiered721Flags.sol';

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
contract JBTiered721Delegate is JB721Delegate, Ownable, IJBTiered721Delegate, IERC2981 {
  using SafeERC20 for IERC20;

  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error CANT_SUPPORT_SPLITS();
  error INCORRECT_DECIMAL_AMOUNT();
  error NOT_AVAILABLE();
  error OVERSPENDING();
  error PRICING_RESOLVER_CHANGES_PAUSED();
  error RESERVED_TOKEN_MINTING_PAUSED();
  error TERMINAL_NOT_FOUND();
  error TRANSFERS_PAUSED();

  //*********************************************************************//
  // ------------------------- public constants ------------------------ //
  //*********************************************************************//
  uint256 public constant MAX_ROYALTY_RATE = 200;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /**
    @notice
    The address of the origin 'JBTiered721Delegate', used to check in the init if the contract is the original or not
  */
  address public override codeOrigin;

  /**
    @notice
    The contract that stores and manages the NFT's data.
  */
  IJBTiered721DelegateStore public override store;

  /**
    @notice
    The contract storing all funding cycle configurations.
  */
  IJBFundingCycleStore public override fundingCycleStore;

  /**
    @notice
    The contract that exposes price feeds.
  */
  IJBPrices public override prices;

  /** 
    @notice
    The currency that is accepted when minting tier NFTs. 
  */
  uint256 public override pricingCurrency;

  /** 
    @notice
    The currency that is accepted when minting tier NFTs. 
  */
  uint256 public override pricingDecimals;

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
    The total number of tokens owned by the given owner across all tiers. 

    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner across all tiers.
  */
  function balanceOf(address _owner) public view override returns (uint256 balance) {
    return store.balanceOf(address(this), _owner);
  }

  /** 
    @notice
    The metadata URI of the provided token ID.

    @dev
    Defer to the tokenUriResolver if set, otherwise, use the tokenUri set with the token's tier.

    @param _tokenId The ID of the token to get the tier URI for. 

    @return The token URI corresponding with the tier or the tokenUriResolver URI.
  */
  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
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
    The cumulative weight the given token IDs have in redemptions compared to the `_totalRedemptionWeight`. 

    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return The weight.
  */
  function redemptionWeightOf(uint256[] memory _tokenIds, JBRedeemParamsData calldata)
    public
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
  function totalRedemptionWeight(JBRedeemParamsData calldata)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return store.totalRedemptionWeight(address(this));
  }

  /**
    @notice
    Indicates if this contract adheres to the specified interface.

    @dev
    See {IERC165-supportsInterface}.

    @param _interfaceId The ID of the interface to check for adherence to.
  */
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(JB721Delegate, IERC165)
    returns (bool)
  {
    return
      _interfaceId == type(IJBTiered721Delegate).interfaceId ||
      super.supportsInterface(_interfaceId);
  }

  /**
    @notice 
    Part of IJBFundingCycleDataSource, this function gets called when the project receives a payment. It will set itself as the delegate to get a callback from the terminal.

    @param _data The Juicebox standard project payment data.

    @return weight The weight that tokens should get minted in accordance with.
    @return memo The memo that should be forwarded to the event.
    @return delegateAllocations The amount to send to delegates instead of adding to the local balance.
  */
  function payParams(JBPayParamsData calldata _data)
    public
    view
    virtual
    override
    returns (
      uint256 weight,
      string memory memo,
      JBPayDelegateAllocation[] memory delegateAllocations
    )
  {
    // Forward the received weight and memo, and use this contract as a pay delegate.
    weight = _data.weight;
    memo = _data.memo;
    delegateAllocations = new JBPayDelegateAllocation[](1);
    delegateAllocations[0] = JBPayDelegateAllocation(this, 0);

    // Send funds that should be forwarded to splits to the delegate.

    // Normalize the currency.
    uint256 _value;
    if (_data.amount.currency == pricingCurrency) _value = _data.amount.value;
    else if (prices != IJBPrices(address(0)))
      _value = PRBMath.mulDiv(
        _data.amount.value,
        10**pricingDecimals,
        prices.priceFor(_data.amount.currency, pricingCurrency, _data.amount.decimals)
      );
    else return (weight, memo, delegateAllocations);

    // Keep a reference to the split orders.
    JB721SplitOrders memory _splitOrders;

    // Skip the first 32 bytes which are used by the JB protocol to pass the paying project's ID when paying from a JBSplit.
    // Skip another 32 bytes reserved for generic extension parameters.
    // Check the 4 bytes interfaceId to verify the metadata is intended for this contract.
    if (
      _data.metadata.length > 68 &&
      bytes4(_data.metadata[64:68]) == type(IJB721Delegate).interfaceId
    ) {
      // Keep a reference to the the specific tier IDs to mint.
      uint16[] memory _tierIdsToMint;

      // Decode the metadata.
      (, , , , _tierIdsToMint) = abi.decode(
        _data.metadata,
        (bytes32, bytes32, bytes4, bool, uint16[])
      );

      // Mint tiers if they were specified.
      if (_tierIdsToMint.length != 0) _splitOrders = store.splitOrdersFor(_tierIdsToMint);
    }

    // If there aren't splits, don't forward anything.
    if (_splitOrders.orders.length == 0) return (weight, memo, delegateAllocations);

    // The percentage of the amount paid that should be forwarded to splits.
    uint256 _splitsAmount = PRBMath.mulDiv(_data.amount.value, _splitOrders.totalValue, _value);

    // Set the delegate to receive the amount to split between.
    delegateAllocations[0].amount = _splitsAmount;

    return (weight, memo, delegateAllocations);
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  constructor() {
    codeOrigin = address(this);
  }

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
  function initialize(
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
  ) public override {
    // Make the original un-initializable.
    if (address(this) == codeOrigin) revert();

    // Stop re-initialization.
    if (address(store) != address(0)) revert();

    // Initialize the superclass.
    JB721Delegate._initialize(_projectId, _directory, _name, _symbol);

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

    // Record adding the provided tiers.
    if (_pricing.tiers.length > 0) _store.recordAddTiers(_pricing.tiers);

    // Set the flags if needed.
    if (
      _flags.lockReservedTokenChanges ||
      _flags.lockVotingUnitChanges ||
      _flags.lockManualMintingChanges ||
      _flags.preventOverspending
    ) _store.recordFlags(_flags);

    // Transfer ownership to the initializer.
    _transferOwnership(msg.sender);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mint reserved tokens within the tier for the provided value.

    @param _mintReservesForTiersData Contains information about how many reserved tokens to mint for each tier.
  */
  function mintReservesFor(JBTiered721MintReservesForTiersData[] calldata _mintReservesForTiersData)
    external
    override
  {
    // Keep a reference to the number of tiers there are to mint reserves for.
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
    Mint tokens within the tier for the provided beneficiaries.

    @param _mintForTiersData Contains information about how who to mint tokens for from each tier.
  */
  function mintFor(JBTiered721MintForTiersData[] calldata _mintForTiersData)
    external
    override
    onlyOwner
  {
    // Keep a reference to the number of beneficiaries there are to mint for.
    uint256 _numberOfBeneficiaries = _mintForTiersData.length;

    for (uint256 _i; _i < _numberOfBeneficiaries; ) {
      // Get a reference to the data being iterated on.
      JBTiered721MintForTiersData calldata _data = _mintForTiersData[_i];

      // Mint for the tier.
      mintFor(_data.tierIds, _data.beneficiary);

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
  }

  /** 
    @notice
    Sets the beneficiary of the reserved tokens for tiers where a specific beneficiary isn't set. 

    @dev
    Only the contract's owner can set the default reserved token beneficiary.

    @param _beneficiary The default beneficiary of the reserved tokens.
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
  function setBaseUri(string calldata _baseUri) external override onlyOwner {
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
    Set an encoded IPFS uri of a tier.

    @dev
    Only the contract's owner can set the encoded IPFS uri.

    @param _tierId The ID of the tier to set the encoded IPFS uri of.
    @param _encodedIPFSUri The encoded IPFS uri to set.
  */
  function setEncodedIPFSUriOf(uint256 _tierId, bytes32 _encodedIPFSUri)
    external
    override
    onlyOwner
  {
    // Store the new value.
    store.recordSetEncodedIPFSUriOf(_tierId, _encodedIPFSUri);

    emit SetEncodedIPFSUri(_tierId, _encodedIPFSUri, msg.sender);
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
    Manually mint NFTs from tiers.

    @param _tierIds The IDs of the tiers to mint from.
    @param _beneficiary The address to mint to. 

    @return tokenIds The IDs of the newly minted tokens.
  */
  function mintFor(uint16[] calldata _tierIds, address _beneficiary)
    public
    override
    onlyOwner
    returns (uint256[] memory tokenIds)
  {
    // Record the mint. The returned token IDs correspond to the tiers passed in.
    (tokenIds, , ) = store.recordMint(
      type(uint256).max, // force the mint.
      _tierIds,
      true // manual mint
    );

    // Keep a reference to the number of tokens being minted.
    uint256 _numberOfTokens = _tierIds.length;

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    for (uint256 _i; _i < _numberOfTokens; ) {
      // Set the token ID.
      _tokenId = tokenIds[_i];

      // Mint the token.
      _mint(_beneficiary, _tokenId);

      emit Mint(_tokenId, _tierIds[_i], _beneficiary, 0, msg.sender);

      unchecked {
        ++_i;
      }
    }
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
    uint256 _leftoverAmount = _value;

    // If the payer is the beneficiary, combine the credits with the paid amount
    // if not, then we keep track of the credits that were unused
    uint256 _stashedCredits;
    if (_data.payer == _data.beneficiary) {
      unchecked {
        _leftoverAmount += _credits;
      }
    } else _stashedCredits = _credits;

    // Keep a reference to the flag indicating if the transaction should not revert if all provided funds aren't spent. Defaults to false, meaning only a minimum payment is enforced.
    bool _allowOverspending;

    // Keep a reference to the split orders.
    JB721SplitOrders memory _splitOrders;

    // Skip the first 32 bytes which are used by the JB protocol to pass the paying project's ID when paying from a JBSplit.
    // Skip another 32 bytes reserved for generic extension parameters.
    // Check the 4 bytes interfaceId to verify the metadata is intended for this contract.
    if (
      _data.metadata.length > 68 &&
      bytes4(_data.metadata[64:68]) == type(IJB721Delegate).interfaceId
    ) {
      // Keep a reference to the the specific tier IDs to mint.
      uint16[] memory _tierIdsToMint;

      // Decode the metadata.
      (, , , _allowOverspending, _tierIdsToMint) = abi.decode(
        _data.metadata,
        (bytes32, bytes32, bytes4, bool, uint16[])
      );

      // Make sure overspending is allowed if requested.
      if (_allowOverspending && store.flagsOf(address(this)).preventOverspending)
        _allowOverspending = false;

      // Mint tiers if they were specified.
      if (_tierIdsToMint.length != 0)
        (_leftoverAmount, _splitOrders) = _mintAll(
          _leftoverAmount,
          _tierIdsToMint,
          _data.beneficiary
        );
    }

    // If there are funds leftover, add to credits.
    if (_leftoverAmount != 0) {
      // Make sure there are no leftover funds after minting if not expected.
      if (!_allowOverspending) revert OVERSPENDING();

      // Increment the leftover amount.
      unchecked {
        creditsOf[_data.beneficiary] = _leftoverAmount + _stashedCredits;
      }
      // Else reset the credits.
    } else if (_credits != _stashedCredits) creditsOf[_data.beneficiary] = _stashedCredits;

    // Store the number of orders.
    uint256 _numberOfOrders = _splitOrders.orders.length;

    // Done if there are no splits to forward to.
    if (_numberOfOrders == 0) return;

    // The contributed value has to be enough to cover the splits. Credits cannot be used to get NFTs with splits.
    if (_splitOrders.totalValue > _value) revert CANT_SUPPORT_SPLITS();

    // Get a reference to the project's owner, who will be the beneficiary of the splits.
    address _projectOwner = directory.projects().ownerOf(projectId);

    for (uint256 _i; _i < _numberOfOrders; ) {
      // The amount to pay the splits being iterated on.
      uint256 _splitAmount = PRBMath.mulDiv(
        _data.forwardedAmount.value,
        _splitOrders.orders[_i].value,
        _splitOrders.totalValue
      );

      // Pay the splits.
      _payTo(
        _splitOrders.orders[_i].splits,
        _data.forwardedAmount.token,
        _splitAmount,
        _data.forwardedAmount.decimals,
        _projectOwner
      );

      unchecked {
        ++_i;
      }
    }

    // Get a reference to any amount leftover in this contract.
    uint256 _leftoverBalance = _data.forwardedAmount.token == JBTokens.ETH
      ? address(this).balance
      : IERC20(_data.forwardedAmount.token).balanceOf(address(this));

    // Send anything leftover back to the project.
    if (_leftoverBalance != 0)
      // Add anything left back to the project's balance.
      _addToBalanceOf(
        projectId,
        _data.forwardedAmount.token,
        _leftoverBalance,
        _data.forwardedAmount.decimals,
        '',
        new bytes(0)
      );
  }

  /** 
    @notice
    A function that will run when tokens are burned via redemption.

    @param _tokenIds The IDs of the tokens that were burned.
  */
  function _didBurn(uint256[] memory _tokenIds) internal virtual override {
    // Add to burned counter.
    store.recordBurn(_tokenIds);
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _mintTierIds An array of tier IDs that are intended to be minted.
    @param _beneficiary The address to mint for.

    @return leftoverAmount The amount leftover after the mint.
    @return splitOrders Instructions for splitting amounts.
  */
  function _mintAll(
    uint256 _amount,
    uint16[] memory _mintTierIds,
    address _beneficiary
  ) internal returns (uint256 leftoverAmount, JB721SplitOrders memory splitOrders) {
    // Keep a reference to the token ID.
    uint256[] memory _tokenIds;

    // Record the mint. The returned token IDs correspond to the tiers passed in.
    (_tokenIds, leftoverAmount, splitOrders) = store.recordMint(
      _amount,
      _mintTierIds,
      false // Not a manual mint
    );

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
    User the hook to register the first owner if it's not yet registered.

    @param _from The address where the transfer is originating.
    @param _to The address to which the transfer is being made.
    @param _tokenId The ID of the token being transferred.
  */
  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal virtual override {
    // Transferred must not be paused when not minting or burning.
    if (_from != address(0)) {
      // Get a reference to the tier.
      JB721Tier memory _tier = store.tierOfTokenId(address(this), _tokenId);

      // Transfers from the tier must be pausable.
      if (_tier.transfersPausable) {
        // Get a reference to the project's current funding cycle.
        JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(projectId);

        if (
          _to != address(0) &&
          JBTiered721FundingCycleMetadataResolver.transfersPaused(
            (JBFundingCycleMetadataResolver.metadata(_fundingCycle))
          )
        ) revert TRANSFERS_PAUSED();
      }

      // If there's no stored first owner, and the transfer isn't originating from the zero address as expected for mints, store the first owner.
      if (store.firstOwnerOf(address(this), _tokenId) == address(0))
        store.recordSetFirstOwnerOf(_tokenId, _from);
    }

    super._beforeTokenTransfer(_from, _to, _tokenId);
  }

  /**
    @notice
    Transfer voting units after the transfer of a token.

    @param _from The address where the transfer is originating.
    @param _to The address to which the transfer is being made.
    @param _tokenId The ID of the token being transferred.
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

    // Handle any other accounting (ex. account for governance voting units)
    _afterTokenTransferAccounting(_from, _to, _tokenId, _tier);

    super._afterTokenTransfer(_from, _to, _tokenId);
  }

  /**
    @notice 
    Custom hook to handle token/tier accounting, this way we can reuse the '_tier' instead of fetching it again.

    @param _from The account to transfer voting units from.
    @param _to The account to transfer voting units to.
    @param _tokenId The ID of the token for which voting units are being transferred.
    @param _tier The tier the token ID is part of.
  */
  function _afterTokenTransferAccounting(
    address _from,
    address _to,
    uint256 _tokenId,
    JB721Tier memory _tier
  ) internal virtual {
    _from; // Prevents unused var compiler and natspec complaints.
    _to;
    _tokenId;
    _tier;
  }

  /**
    @notice 
    Royalty info conforming to EIP-2981.

    @param _tokenId The ID of the token that the royalty is for.
    @param _salePrice The price being paid for the token.

    @return receiver The address of the royalty's receiver.
    @return royaltyAmount The amount of the royalty.
  */
  function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
    external
    view
    override
    returns (address receiver, uint256 royaltyAmount)
  {
    // Get a reference to the tier.
    JB721Tier memory _tier = store.tier(address(this), _tokenId);

    // Get a reference to the beneficiary.
    address _beneficiary = store.royaltyBeneficiaryOf(address(this), _tier.id);

    // If no beneificary, return no royalty.
    if (_beneficiary == address(0)) return (address(0), 0);

    // Return the royalty portion of the sale.
    return (_beneficiary, PRBMath.mulDiv(_salePrice, _tier.royaltyRate, MAX_ROYALTY_RATE));
  }

  /** 
    @notice 
    Split an amount between all splits.

    @param _splits The splits.
    @param _token The token the amonut being split is in.
    @param _amount The amount of tokens being split, as a fixed point number. If the `_token` is ETH, this is ignored and msg.value is used in its place.
    @param _decimals The number of decimals in the `_amount` fixed point number. 
    @param _defaultBeneficiary The address that will benefit from any non-specified beneficiaries in splits.

    @return leftoverAmount The amount leftover after all splits were paid.
  */
  function _payTo(
    JBSplit[] memory _splits,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    address _defaultBeneficiary
  ) internal virtual returns (uint256 leftoverAmount) {
    // Set the leftover amount to the initial balance.
    leftoverAmount = _amount;

    // Settle between all splits.
    for (uint256 i; i < _splits.length; ) {
      // Get a reference to the split being iterated on.
      JBSplit memory _split = _splits[i];

      // The amount to send towards the split.
      uint256 _splitAmount = PRBMath.mulDiv(
        _amount,
        _split.percent,
        JBConstants.SPLITS_TOTAL_PERCENT
      );

      if (_splitAmount > 0) {
        // Transfer tokens to the split.
        // If there's an allocator set, transfer to its `allocate` function.
        if (_split.allocator != IJBSplitAllocator(address(0))) {
          // Create the data to send to the allocator.
          JBSplitAllocationData memory _data = JBSplitAllocationData(
            _token,
            _splitAmount,
            _decimals,
            projectId,
            0,
            _split
          );

          // Approve the `_amount` of tokens for the split allocator to transfer tokens from this contract.
          if (_token != JBTokens.ETH)
            IERC20(_token).safeApprove(address(_split.allocator), _splitAmount);

          // If the token is ETH, send it in msg.value.
          uint256 _payableValue = _token == JBTokens.ETH ? _splitAmount : 0;

          // Trigger the allocator's `allocate` function.
          _split.allocator.allocate{value: _payableValue}(_data);

          // Otherwise, if a project is specified, make a payment to it.
        } else if (_split.projectId != 0) {
          // Send the projectId in the metadata.
          bytes memory _projectMetadata = new bytes(32);
          _projectMetadata = bytes(abi.encodePacked(projectId));

          if (_split.preferAddToBalance)
            _addToBalanceOf(
              _split.projectId,
              _token,
              _splitAmount,
              _decimals,
              '',
              _projectMetadata
            );
          else
            _pay(
              _split.projectId,
              _token,
              _splitAmount,
              _decimals,
              _split.beneficiary != address(0) ? _split.beneficiary : _defaultBeneficiary,
              0,
              _split.preferClaimed,
              '',
              _projectMetadata
            );
        } else {
          // Transfer the ETH.
          if (_token == JBTokens.ETH)
            Address.sendValue(
              // Get a reference to the address receiving the tokens. If there's a beneficiary, send the funds directly to the beneficiary. Otherwise send to _defaultBeneficiary.
              _split.beneficiary != address(0) ? _split.beneficiary : payable(_defaultBeneficiary),
              _splitAmount
            );
            // Or, transfer the ERC20.
          else {
            IERC20(_token).safeTransfer(
              // Get a reference to the address receiving the tokens. If there's a beneficiary, send the funds directly to the beneficiary. Otherwise send to _defaultBeneficiary.
              _split.beneficiary != address(0) ? _split.beneficiary : _defaultBeneficiary,
              _splitAmount
            );
          }
        }

        // Subtract from the amount to be sent to the beneficiary.
        leftoverAmount = leftoverAmount - _splitAmount;
      }

      emit DistributeToSplit(_split, _splitAmount, _defaultBeneficiary, msg.sender);

      unchecked {
        ++i;
      }
    }
  }

  /** 
    @notice 
    Make a payment to the specified project.

    @param _projectId The ID of the project that is being paid.
    @param _token The token being paid in.
    @param _amount The amount of tokens being paid, as a fixed point number. 
    @param _decimals The number of decimals in the `_amount` fixed point number. 
    @param _beneficiary The address who will receive tokens from the payment.
    @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with 18 decimals.
    @param _preferClaimedTokens A flag indicating whether the request prefers to mint project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
    @param _memo A memo to pass along to the emitted event, and passed along the the funding cycle's data source and delegate.  A data source can alter the memo before emitting in the event and forwarding to the delegate.
    @param _metadata Bytes to send along to the data source and delegate, if provided.
  */
  function _pay(
    uint256 _projectId,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string memory _memo,
    bytes memory _metadata
  ) internal virtual {
    // Find the terminal for the specified project.
    IJBPaymentTerminal _terminal = directory.primaryTerminalOf(_projectId, _token);

    // There must be a terminal.
    if (_terminal == IJBPaymentTerminal(address(0))) revert TERMINAL_NOT_FOUND();

    // The amount's decimals must match the terminal's expected decimals.
    if (_terminal.decimalsForToken(_token) != _decimals) revert INCORRECT_DECIMAL_AMOUNT();

    // Approve the `_amount` of tokens from the destination terminal to transfer tokens from this contract.
    if (_token != JBTokens.ETH) IERC20(_token).safeApprove(address(_terminal), _amount);

    // If the token is ETH, send it in msg.value.
    uint256 _payableValue = _token == JBTokens.ETH ? _amount : 0;

    // Send funds to the terminal.
    // If the token is ETH, send it in msg.value.
    _terminal.pay{value: _payableValue}(
      _projectId,
      _amount, // ignored if the token is JBTokens.ETH.
      _token,
      _beneficiary,
      _minReturnedTokens,
      _preferClaimedTokens,
      _memo,
      _metadata
    );
  }

  /** 
    @notice 
    Add to the balance of the specified project.

    @param _projectId The ID of the project that is being paid.
    @param _token The token being paid in.
    @param _amount The amount of tokens being paid, as a fixed point number. If the token is ETH, this is ignored and msg.value is used in its place.
    @param _decimals The number of decimals in the `_amount` fixed point number. If the token is ETH, this is ignored and 18 is used in its place, which corresponds to the amount of decimals expected in msg.value.
    @param _memo A memo to pass along to the emitted event.
    @param _metadata Extra data to pass along to the terminal.
  */
  function _addToBalanceOf(
    uint256 _projectId,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    string memory _memo,
    bytes memory _metadata
  ) internal virtual {
    // Find the terminal for the specified project.
    IJBPaymentTerminal _terminal = directory.primaryTerminalOf(_projectId, _token);

    // There must be a terminal.
    if (_terminal == IJBPaymentTerminal(address(0))) revert TERMINAL_NOT_FOUND();

    // The amount's decimals must match the terminal's expected decimals.
    if (_terminal.decimalsForToken(_token) != _decimals) revert INCORRECT_DECIMAL_AMOUNT();

    // Approve the `_amount` of tokens from the destination terminal to transfer tokens from this contract.
    if (_token != JBTokens.ETH) IERC20(_token).safeApprove(address(_terminal), _amount);

    // If the token is ETH, send it in msg.value.
    uint256 _payableValue = _token == JBTokens.ETH ? _amount : 0;

    // Add to balance so tokens don't get issued.
    _terminal.addToBalanceOf{value: _payableValue}(_projectId, _amount, _token, _memo, _metadata);
  }
}
