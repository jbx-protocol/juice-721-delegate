// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

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
  JBNFTRewardDataSource,
  IJBTieredLimitedNFTRewardDataSource,
  ITokenSupplyDetails
{
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INSUFFICIENT_AMOUNT();
  error OUT();
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
    The reward tiers. 

    _tierId The incremental ID of the tier. Ordered by contribution floor, starting with 1.
  */
  mapping(uint256 => JBNFTRewardTier) public tiers;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply() external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    for (uint256 _i; _i < numberOfTiers; ) {
      // Set the tier being iterated on.
      _tier = tiers[_i];

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
    return ownerOf(_tokenId) != address(0) ? 1 : 0;
  }

  /** 
    @notice 
    The total number of tokens owned by the given owner. 
    @param _owner The address to check the balance of.
    @return The number of tokens owners by the owner.
  */
  function totalOwnerBalance(address _owner) external view override returns (uint256) {
    return balanceOf(_owner);
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
    return ownerOf(_tokenId) == _owner ? 1 : 0;
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
    if (ownerOf(_tokenId) == address(0)) return '';

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(tokenUriResolver) != address(0)) return tokenUriResolver.getUri(_tokenId);

    // The baseUri is added to the JBNFTRewardTier for each tier.
    return tiers[tierIdOfToken(_tokenId)].baseUri;
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
    @param _tiers The tiers according to which token distribution will be made. 
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
    JBNFTRewardTier[] memory _tiers
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
    numberOfTiers = _tiers.length;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    for (uint256 _i; _i < numberOfTiers; ) {
      // Set the tier being iterated on.
      _tier = _tiers[_i];

      // Make sure there is some quantity.
      if (_tier.remainingQuantity == 0) revert NO_QUANTITY();

      // Make sure the tier's contribution floor is greater than or equal to the previous contribution floor.
      if (_i != 0 && _tier.contributionFloor < _tiers[_i - 1].contributionFloor)
        revert INVALID_PRICE_SORT_ORDER();

      // Set the initial quantity to be the remaining quantity.
      _tier.initialQuantity = _tier.remainingQuantity;

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

    @param _beneficiary The address that should receive to token.
    @param _tierId The ID of the tier to mint within.
    @param _tokenNumber The token number to use for the mint, which cannot be a token number within the tier's initial quantity.
  */
  function mint(
    address _beneficiary,
    uint256 _tierId,
    uint256 _tokenNumber
  ) external override onlyOwner returns (uint256 tokenId) {
    // Make sure the token number is greater than the tier's initial quantity.
    if (_tokenNumber <= tiers[_tierId].initialQuantity) revert NOT_AVAILABLE();

    // Keep a reference to the token ID.
    tokenId = _generateTokenId(_tierId, _tokenNumber);

    // Mint it.
    _mint(_beneficiary, tokenId);

    emit Mint(tokenId, _tierId, _beneficiary, 0, 1, msg.sender);
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

    @dev
    `_data.metadata` should include the number of rewards being requested in bits 32-39.

    @param _data The Juicebox standard project contribution data.
  */
  function _processContribution(JBDidPayData calldata _data) internal override {
    // Make the contribution is being made in the expected token.
    if (_data.amount.token != contributionToken) return;

    // Keep a reference to the number of rewards being processed. Skip the first 32 bits which are used by the JB protocol.
    uint256 _numRewards = uint256(uint8(_bytesToUint(_data.metadata) << 32));

    // Keep a reference to the value remaining.
    uint256 _remainingValue = _data.amount.value;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    for (uint256 _i; _i < _numRewards; ) {
      // Tier IDs are in chuncks of 32 bits starting in bit 40.
      _tierId = uint256(uint32(_bytesToUint(_data.metadata) << (40 + 32 * _i)));

      // If no tier specified, accept the funds without minting anything.
      if (_tierId == 0) continue;

      // Keep a reference to the tier being iterated on.
      JBNFTRewardTier storage _tier = tiers[_tierId];

      // Make sure the provided tier exists.
      if (_tier.initialQuantity == 0) revert INVALID_TIER();

      // Make sure the amount meets the tier's contribution floor.
      if (_tier.contributionFloor > _remainingValue) revert INSUFFICIENT_AMOUNT();

      // Make sure there are enough units available.
      if (_tier.remainingQuantity == 0) revert OUT();

      unchecked {
        // Keep a reference to the token ID.
        _tokenId = _generateTokenId(_tierId, _tier.initialQuantity - --_tier.remainingQuantity);

        // Decrement the remaining value.
        _remainingValue = _remainingValue - _tier.contributionFloor;
      }

      // If there's a token to mint, do so and increment the tier supply.
      _mint(_data.beneficiary, _tokenId);

      emit Mint(_tokenId, _tierId, _data.beneficiary, _data.amount.value, _numRewards, msg.sender);

      unchecked {
        ++_i;
      }
    }
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
    returns (uint256 tokenId)
  {
    // The tier ID in the first 32 bits.
    tokenId = _tierId;

    // The token number in the rest.
    tokenId |= _tokenNumber << 32;
  }

  // From https://ethereum.stackexchange.com/questions/51229/how-to-convert-bytes-to-uint-in-solidity
  function _bytesToUint(bytes memory _bytes) internal pure returns (uint256 number) {
    for (uint256 _i; _i < _bytes.length; _i++)
      number = number + uint256(uint8(_bytes[_i])) * (2**(8 * (_bytes.length - (_i + 1))));
  }
}
