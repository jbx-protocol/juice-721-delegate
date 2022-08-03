// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBConstants.sol';
import '@openzeppelin/contracts/governance/utils/Votes.sol';
import './abstract/JBNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import './libraries/JBIpfsDecoder.sol';

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
  JBNFTRewardDataSource,
  Votes,
  Ownable
{
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error OVERSPENDING();

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /**
    @notice
    The contract that stores and manages the nft's data.
  */
  IJBTieredLimitedNFTRewardDataSourceStore public immutable override store;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The total number of tokens owned by the given owner. 

    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner accross all tiers.
  */
  function balanceOf(address _owner) public view override returns (uint256 balance) {
    return store.balanceOf(address(this), _owner);
  }

  /**
    @notice
    The first owner of each token ID.

    @param _tokenId The ID of the token to get the stored first owner of.

    @return The first owner of the token.
  */
  function firstOwnerOf(uint256 _tokenId) external view override returns (address) {
    // Get a reference to the first owner.
    address _storedFirstOwner = store.firstOwnerOf(address(this), _tokenId);

    // If the stored first owner is set, return it.
    if (_storedFirstOwner != address(0)) return _storedFirstOwner;

    // Otherwise the first owner must be the current owner.
    return _owners[_tokenId];
  }

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

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

    // Get a reference to the URI resolver.
    IJBTokenUriResolver _resolver = store.tokenUriResolverOf(address(this));

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(_resolver) != address(0)) return _resolver.getUri(_tokenId);

    // Return the token URI for the token's tier.
    return
      JBIpfsDecoder.decode(
        store.baseUriOf(address(this)),
        store.tierOfTokenId(address(this), _tokenId).data.tokenUri
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
      _interfaceId == type(IJBTieredLimitedNFTRewardDataSource).interfaceId ||
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
    @param _baseUri A URI to use as a base for full token URIs.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _owner The address that should own this contract.
    @param _tierData The tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _store A contract that stores the NFT's data.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    string memory _baseUri,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    address _owner,
    JBNFTRewardTierData[] memory _tierData,
    IJBTieredLimitedNFTRewardDataSourceStore _store
  ) JBNFTRewardDataSource(_projectId, _directory, _name, _symbol) EIP712(_name, '1') {
    store = _store;

    if (bytes(_baseUri).length != 0) _store.recordSetBaseUri(_baseUri);
    if (bytes(_contractUri).length != 0) _store.recordSetContractUri(_contractUri);
    if (_tokenUriResolver != IJBTokenUriResolver(address(0)))
      _store.recordSetTokenUriResolver(_tokenUriResolver);

    _store.recordAddTierData(_tierData, true);

    // Transfer the ownership to the specified address.
    if (_owner != address(0)) _transferOwnership(_owner);
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
    address _reservedTokenBeneficiary = store.reservedTokenBeneficiary(address(this));

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
    Adjust the tiers mintable in this contract, adhering to any locked tier constraints. 

    @param _tierDataToAdd An array of tier data to add.
    @param _tierIdsToRemove An array of tier IDs to remove.
  */
  function adjustTiers(
    JBNFTRewardTierData[] calldata _tierDataToAdd,
    uint256[] calldata _tierIdsToRemove
  ) external override onlyOwner {
    // Get a reference to the number of tiers being added.
    uint256 _numberOfTiersToAdd = _tierDataToAdd.length;

    // Add tiers.
    if (_numberOfTiersToAdd != 0) {
      uint256[] memory _tierIdsAdded = store.recordAddTierData(_tierDataToAdd, false);

      for (uint256 _i; _i < _numberOfTiersToAdd; ) {
        emit AddTier(_tierIdsAdded[_i], _tierDataToAdd[_i], msg.sender);
        unchecked {
          ++_i;
        }
      }
    }

    // Get a reference to the number of tiers being removed.
    uint256 _numberOfTiersToRemove = _tierIdsToRemove.length;

    // Remove tiers.
    if (_numberOfTiersToRemove != 0) {
      store.recordRemoveTierIds(_tierIdsToRemove);

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
    Sets the beneificiary of the reserved tokens. 

    @param _beneficiary The beneificiary of the reserved tokens.
  */
  function setReservedTokenBeneficiary(address _beneficiary) external override onlyOwner {
    // Set the beneficiary.
    store.recordSetReservedTokenBeneficiary(_beneficiary);

    emit SetReservedTokenBeneficiary(_beneficiary, msg.sender);
  }

  /**
    @notice
    Set a base token URI.

    @dev
    Only the contract's owner can set the token URI resolver.

    @param _baseUri The new base URI.
  */
  function setBaseUri(string memory _baseUri) external override onlyOwner {
    // Store the new value.
    store.recordSetBaseUri(_baseUri);

    emit SetBaseUri(_baseUri, msg.sender);
  }

  /**
    @notice
    Set a contract metadata uri to contain opensea-style metadata.

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
  function _processPayment(JBDidPayData calldata _data) internal override {
    // Make sure the contribution is being made in the expected token.
    if (_data.amount.token != JBTokens.ETH) return;

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
    (_tokenId, _tierId, leftoverAmount) = store.recordMintBestAvailableTier(_amount, _expectMint);

    // If there's no best tier, return.
    if (_tokenId == 0) return _amount;

    // Mint the tokens.
    _mint(_beneficiary, _tokenId);

    emit Mint(_tokenId, _tierId, _beneficiary, _amount - leftoverAmount, 0, msg.sender);
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _mintTierIds An array of tier IDs that the user wants to mint
    @param _beneficiary The address to mint for.

    @return leftoverAmount The amount leftover after the mint.
  */
  function _mintAll(
    uint256 _amount,
    uint8[] memory _mintTierIds,
    address _beneficiary
  ) internal returns (uint256 leftoverAmount) {
    // Keep a reference to the token ID.
    uint256[] memory _tokenIds;

    // Record the mint. The returned token IDs correspond to the tiers passed in.
    (_tokenIds, leftoverAmount) = store.recordMint(_amount, _mintTierIds);

    uint256 _mintsLength = _tokenIds.length;

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    for (uint256 _i; _i < _mintsLength; ) {
      // Get a reference to the tier being iterated on.
      _tokenId = _tokenIds[_i];

      // Mint the tokens.
      _mint(_beneficiary, _tokenId);

      emit Mint(_tokenId, _mintTierIds[_i], _beneficiary, _amount, _mintsLength, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `totalRedemptionWeight`. 

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

  /**
    @notice
    User the hook to register the first owner if it's not yet regitered.
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
    JBNFTRewardTier memory _tier = store.tierOfTokenId(address(this), _tokenId);

    store.recordTransferForTier(_tier.id, _from, _to);

    if (_tier.data.votingUnits != 0)
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _tier.data.votingUnits);

    super._afterTokenTransfer(_from, _to, _tokenId);
  }

  /** 
    @notice
    The stored base URI. 

    @return The URI.
  */
  function _baseURI() internal view virtual override returns (string memory) {
    return store.baseUriOf(address(this));
  }
}
