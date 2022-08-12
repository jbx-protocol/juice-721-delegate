// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './abstract/JB721Delegate.sol';
import './abstract/Votes.sol';
import './interfaces/IJBTiered721Delegate.sol';
import './libraries/JBIpfsDecoder.sol';

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
    The token that is accepted when minting NFTs. 
  */
  address public immutable override contributionToken = JBTokens.ETH;

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
    @param _baseUri A URI to use as a base for full token URIs.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _tiers The tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _store A contract that stores the NFT's data.
    @param _lockReservedTokenChanges A flag indicating if reserved tokens can change over time by adding new tiers with a reserved rate.
    @param _lockVotingUnitChanges A flag indicating if voting unit expectations can change over time by adding new tiers with voting units.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    string memory _baseUri,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    JB721TierParams[] memory _tiers,
    IJBTiered721DelegateStore _store,
    bool _lockReservedTokenChanges,
    bool _lockVotingUnitChanges
  ) JB721Delegate(_projectId, _directory, _name, _symbol) EIP712(_name, '1') {
    store = _store;

    // Store the base URI if provided.
    if (bytes(_baseUri).length != 0) _store.recordSetBaseUri(_baseUri);

    // Set the contract URI if provided.
    if (bytes(_contractUri).length != 0) _store.recordSetContractUri(_contractUri);

    // Set the token URI resolver if provided.
    if (_tokenUriResolver != IJBTokenUriResolver(address(0)))
      _store.recordSetTokenUriResolver(_tokenUriResolver);

    // Record adding the provided tiers.
    if (_tiers.length > 0) _store.recordAddTiers(_tiers);

    // Set the locked reserved token change preference if needed.
    if (_lockReservedTokenChanges) _store.recordLockReservedTokenChanges(_lockReservedTokenChanges);

    // Set the locked voting unit change preference if needed.
    if (_lockVotingUnitChanges) _store.recordLockVotingUnitChanges(_lockVotingUnitChanges);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mint reserved tokens within the tier for the provided value.

    @param _tierId The ID of the tier to mint within.
    @param _count The number of reserved tokens to mint. 
  */
  function mintReservesFor(uint256 _tierId, uint256 _count) external override {
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

    @param _tokenUriResolver The new base URI.
  */
  function setTokenUriResolver(IJBTokenUriResolver _tokenUriResolver) external override onlyOwner {
    // Store the new value.
    store.recordSetTokenUriResolver(_tokenUriResolver);

    emit SetTokenUriResolver(_tokenUriResolver, msg.sender);
  }

  /**
    @notice 
    Delegates votes from the sender to `delegatee`.

    @param _delegatee The account to delegate tier voting units to.
    @param _tierId The ID of the tier to delegate voting units for.
   */
  function delegateTier(address _delegatee, uint256 _tierId) public virtual override {
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
    // Make sure the contribution is being made in the expected token.
    if (_data.amount.token != contributionToken) return;

    // Set the leftover amount as the initial value.
    uint256 _leftoverAmount = _data.amount.value;

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

    @return  leftoverAmount The amount leftover after the mint.
  */
  function _mintBestAvailableTier(
    uint256 _amount,
    address _beneficiary,
    bool _expectMint
  ) internal returns (uint256 leftoverAmount) {
    // Keep a reference to the token ID.
    uint256 _tokenId;

    // Keep a reference to the tier ID.
    uint256 _tierId;

    // Record the mint.
    (_tokenId, _tierId, leftoverAmount) = store.recordMintBestAvailableTier(_amount);

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
    @param _mintTierIds An array of tier IDs that are intended to be minted.
    @param _beneficiary The address to mint for.

    @return leftoverAmount The amount leftover after the mint.
  */
  function _mintAll(
    uint256 _amount,
    uint16[] memory _mintTierIds,
    address _beneficiary
  ) internal returns (uint256 leftoverAmount) {
    // Keep a reference to the token ID.
    uint256[] memory _tokenIds;

    // Record the mint. The returned token IDs correspond to the tiers passed in.
    (_tokenIds, leftoverAmount) = store.recordMint(_amount, _mintTierIds);

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
    address oldDelegate = delegates(_account);
    _tierDelegation[_account][_tierId] = _delegatee;

    emit DelegateChanged(_account, oldDelegate, _delegatee);
    _moveTierDelegateVotes(
      oldDelegate,
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
    if (_from == address(0)) _totalTierCheckpoints[_tierId].push(_add, _amount);
    if (_to == address(0)) _totalTierCheckpoints[_tierId].push(_subtract, _amount);
    _moveTierDelegateVotes(delegates(_from), delegates(_to), _tierId, _amount);
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
    if (_from != _to && _amount > 0) {
      if (_from != address(0)) {
        (uint256 oldValue, uint256 newValue) = _delegateTierCheckpoints[_from][_tierId].push(
          _subtract,
          _amount
        );
        emit TierDelegateVotesChanged(_from, oldValue, newValue, _tierId, msg.sender);
      }
      if (_to != address(0)) {
        (uint256 oldValue, uint256 newValue) = _delegateTierCheckpoints[_to][_tierId].push(
          _add,
          _amount
        );
        emit TierDelegateVotesChanged(_to, _tierId, oldValue, newValue, msg.sender);
      }
    }
  }
}
