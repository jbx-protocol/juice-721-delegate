// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './abstract/JBNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSource.sol';

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
  JBNFTRewardDataSource,
  IJBTieredLimitedNFTRewardDataSource
{
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error NOT_AVAILABLE();
  error INSUFFICIENT_AMOUNT();
  error OUT();
  error INVALID_TIER();
  error INVALID_PRICE_SORT_ORDER();
  error NO_QUANTITY();

  //*********************************************************************//
  // --------------------- internal stored properties ------------------ //
  //*********************************************************************//

  /** 
    @notice
    The reward tiers. 
  */
  JBNFTRewardTier[] internal _tiers;

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /** 
    @notice
    The token to expect contributions to be made in.
  */
  address public immutable override contributionToken;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The reward tiers.

    @return The tiers. 
  */
  function tiers() external view override returns (JBNFTRewardTier[] memory) {
    return _tiers;
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply() external view override returns (uint256 supply) {
    // Keep a reference to the number of tiers.
    uint256 _numTiers = _tiers.length;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on.
      _tier = _tiers[_i];

      // Increment the total supply with the amount used already.
      supply += _tier.initialQuantity - _tier.remainingQuantity;

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice 
    The total number of tokens with the given ID.

    @return Either 1 if the token has been minted, or 0 if it hasnt.
  */
  function tokenSupply(uint256 _tokenId) external view override returns (uint256) {
    return _ownerOf[_tokenId] != address(0) ? 1 : 0;
  }

  /** 
    @notice 
    The total number of tokens owned by the given owner. 

    @param _owner The address to check the balance of.

    @return The number of tokens owners by the owner.
  */
  function totalOwnerBalance(address _owner) external view override returns (uint256) {
    return _balanceOf[_owner];
  }

  /** 
    @notice 
    The total number of tokens with the given ID owned by the given owner. 

    @param _owner The address to check the balance of.
    @param _tokenId The ID of the token to check the owner's balance of.

    @return Either 1 if the owner has the token, or 0 if it does not.
  */
  function ownerTokenBalance(address _owner, uint256 _tokenId)
    external
    view
    override
    returns (uint256)
  {
    return _ownerOf[_tokenId] == _owner ? 1 : 0;
  }

  /** 
    @notice
    The amount paid for the provided token ID. 

    @param _tokenId The ID of the token to get the price paid for. 

    @return The price paid for the specified token ID, as a fixed point number with 18 decimals.
  */
  function pricePaidForToken(uint256 _tokenId) public view override returns (uint256) {
    // The price is in the last 160 bits.
    return uint256(uint96(_tokenId));
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
  function tierIdOfToken(uint256 _tokenId) public view override returns (uint256) {
    // The tier ID is in the first 32 bytes.
    return uint256(uint32(_tokenId));
  }

  /** 
    @notice
    TokenURI of the provided token ID.

    @dev
    Defer to the tokenUriResolver, if set, otherwise, use the tokenUri set with the tier.

    @param _tokenId The ID of the token to get the tier tokenUri for. 

    @return The baseUri corresponding with the tier or the tokenUriResolver Uri.
  */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    // A token without an owner doesn't have a URI.
    if (_ownerOf[_tokenId] == address(0)) return '';

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(tokenUriResolver) != address(0)) return tokenUriResolver.getUri(_tokenId);

    // The baseUri is added to the JBNFTRewardTier for each tier.
    return _tiers[tierIdOfToken(_tokenId)].baseUri;
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
    @param _baseUri The token's base URI, to be used if a URI resolver is not provided. 
    @param _contractUri A URI where contract metadata can be found. 
    @param _owner The address that should own this contract.
    @param _contributionToken The token that contributions are expected to be in terms of.
    @param __tiers The tiers according to which token distribution will be made. 
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _baseUri,
    string memory _contractUri,
    address _owner,
    address _contributionToken,
    JBNFTRewardTier[] memory __tiers
  )
    JBNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _baseUri,
      _contractUri,
      _owner
    )
  {
    contributionToken = _contributionToken;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    // Keep a reference to the number of tiers.
    uint256 _numTiers = __tiers.length;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on.
      _tier = __tiers[_i];

      // Make sure there is some quantity.
      if (_tier.remainingQuantity == 0) revert NO_QUANTITY();

      // Make sure the tier's contribution floor is greater than or equal to the previous contribution floor.
      if (_i != 0 && _tier.contributionFloor < __tiers[_i - 1].contributionFloor)
        revert INVALID_PRICE_SORT_ORDER();

      // Set the initial quantity to be the remaining quantity.
      _tier.initialQuantity = _tier.remainingQuantity;

      // Add the tier with the iterative ID.
      _tiers[_i] = _tier;

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

    @param _beneficiary The address that should receive to token.
    @param _tierId The ID of the tier to mint within.
  */
  function mint(address _beneficiary, uint256 _tierId)
    external
    override
    onlyOwner
    returns (uint256 tokenId)
  {
    // Keep a reference to the token ID.
    tokenId = _generateTokenId(type(uint256).max, _tierId, false);

    // Make sure there's a token ID.
    if (tokenId == 0) revert NOT_AVAILABLE();

    // Mint it.
    _mint(_beneficiary, tokenId);

    emit Mint(tokenId, _tierId, _beneficiary, type(uint256).max, msg.sender);
  }

  /** 
    @notice
    Burns a token ID from an account.

    @dev
    Only a project owner can burn tokens.

    @param _owner The address that owns the token being burned.
    @param _tokenId The ID of the token to burn.
  */
  function burn(address _owner, uint256 _tokenId) external override onlyOwner {
    // Burn the token and decrease the supply.
    _burn(_tokenId);

    emit Burn(_tokenId, _owner, msg.sender);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /**
    @notice 
    Mints a token for a given contribution to the beneficiary.

    @param _data The Juicebox standard project contribution data.
  */
  function _processContribution(JBDidPayData calldata _data) internal override {
    // Make the contribution is being made in the expected token.
    if (_data.amount.token != contributionToken) return;

    // Tier ID is in bits 32-63.
    uint256 _tierId = uint256(uint32(_bytesToUint(_data.metadata) << 32));

    // If no tier specified, accept the funds without minting anything.
    if (_tierId == 0) return;

    // Keep a reference to the token ID.
    uint256 _tokenId = _generateTokenId(_data.amount.value, _tierId, true);

    // If there's a token to mint, do so and increment the tier supply.
    _mint(_data.beneficiary, _tokenId);

    emit Mint(_tokenId, _tierId, _data.beneficiary, _data.amount.value, msg.sender);
  }

  /** 
    @notice
    Finds the token ID and tier given a contribution amount. 

    @param _amount The amount of the contribution.
    @param _tierId The ID of the tier to generate an ID for.
    @param _enforceMaxQuantity Whether the token's max quantity should be respected.

    @return tokenId The ID of the token.
  */
  function _generateTokenId(
    uint256 _amount,
    uint256 _tierId,
    bool _enforceMaxQuantity
  ) internal returns (uint256 tokenId) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier storage _tier = _tiers[_tierId];

    // Make sure the provided tier exists.
    if (_tier.initialQuantity == 0) revert INVALID_TIER();

    // Make sure the amount meets the tier's contribution floor.
    if (_tier.contributionFloor > _amount) revert INSUFFICIENT_AMOUNT();

    // Make sure there are enough units available.
    if (_enforceMaxQuantity && _tier.remainingQuantity == 0) revert OUT();

    // The tier ID in the first 32 bits.
    tokenId = _tierId;

    unchecked {
      // The token ID incrementally increases in bits 32-95.
      tokenId |= (_tier.initialQuantity - --_tier.remainingQuantity) << 32;
    }

    // The amount paid can take up the rest.
    tokenId |= _amount << 96;
  }

  // From https://ethereum.stackexchange.com/questions/51229/how-to-convert-bytes-to-uint-in-solidity
  function _bytesToUint(bytes memory _bytes) internal pure returns (uint256 number) {
    for (uint256 _i; _i < _bytes.length; _i++)
      number = number + uint256(uint8(_bytes[_i])) * (2**(8 * (_bytes.length - (_i + 1))));
  }
}
