// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './interfaces/IJBTokenUriResolver.sol';
import './structs/JBNFTRewardTier.sol';

/**
  @title
  JBTokenUriResolver

  @notice
  TokenUriResolver for JBTieredLimitedNFTRewardDataSource which maps a single URI to each tier.

  @notice 
  This contract allows for setting the TokenURI for each tier. 
  Intended use is to incentivize initial project support by minting a limited number of NFTs to the first N contributors among various price tiers.
*/
contract JBTokenUriResolver is IJBTokenUriResolver {
  JBNFTRewardTier[] tiers;
  string[] tokenUris;

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The tokenURI function which returns the Uri of a token.
    
    @param _tokenId The ID of the token to get the tier number of. 

    @return The tokenUri of the token by tier.
  */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    return tokenUris[tierNumberOfToken(_tokenId)];
  }

  /**    
    @param _tokenUris An array of tokenUris.    
  */
  constructor(JBNFTRewardTier[] memory _tiers, string[] memory _tokenUris) {
    // Keep a reference to the tier being iterated on.
    for (uint256 _i; _i < _tiers.length; ) {
      // Set the tier being iterated on.
      tiers.push(_tiers[_i]);
      unchecked {
        ++_i;
      }
    }

    for (uint256 _i; _i < _tokenUris.length; ) {
      tokenUris.push(_tokenUris[_i]);
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
  function tierNumberOfToken(uint256 _tokenId) public view returns (uint256) {
    // Keep a reference to the number of tiers.
    uint256 _numTiers = tiers.length;

    // Keep a reference to the tier being iterated on.
    JBNFTRewardTier memory _tier;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on.
      _tier = tiers[_i];

      // If the token ID is less than the tier's cieling and greater than this tier's starting, and greater than the previous tier's ceiling, it's in this tier.
      if (
        _tier.idCeiling > _tokenId && _tier.idCeiling - _tier.initialAllowance <= _tokenId
        // 1 indexed, meaning the 0th element of the array is tier 1.
      ) return _i + 1;

      unchecked {
        ++_i;
      }
    }

    return 0;
  }
}
