// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// import './abstract/AbstractNFTRewardDelegate.sol';

// /**
//   @title Juicebox data source delegate that offers project contributors NFTs.

//   @notice This contract allows project creators to reward contributors with NFTs. Intended use is to incentivize initial project support by minting a limited number of NFTs to the first N contributors.

//   @notice One use case is enabling the project to mint an NFT for anyone contributing any amount without a mint limit. Set minContribution.value to 0 and maxSupply to uint256.max to do this. To mint NFTs to the first 100 participants contributing 1000 DAI or more, set minContribution.value to 1000000000000000000000 (3 + 18 zeros), minContribution.token to 0x6B175474E89094C44Da98b954EedeAC495271d0F and maxSupply to 100.

//   @dev Keep in mind that this PayDelegate and RedeemDelegate implementation will simply pass through the weight and reclaimAmount it is called with.
//  */
// contract SimpleNFTRewardDelegate is AbstractNFTRewardDelegate {
//   /**
//     @notice Minimum contribution amount to trigger NFT distribution, denominated in some currency defined as part of this object.

//     @dev Only one NFT will be minted for any amount at or above this value.
//   */
//   JBTokenAmount internal _minContribution;

//   constructor(
//     uint256 projectId,
//     IJBDirectory directory,
//     uint256 maxSupply,
//     string memory _name,
//     string memory _symbol,
//     string memory _uri,
//     IToken721UriResolver _tokenUriResolverAddress,
//     string memory _contractMetadataUri,
//     address _admin,
//     JBTokenAmount memory minContribution
//   )
//     AbstractNFTRewardDelegate(
//       projectId,
//       directory,
//       maxSupply,
//       _name,
//       _symbol,
//       _uri,
//       _tokenUriResolverAddress,
//       _contractMetadataUri,
//       _admin
//     )
//   {
//     _minContribution = minContribution;
//   }

//   /**
//    */
//   function validateContribution(address account, JBTokenAmount calldata contribution)
//     internal
//     override
//   {
//     if (
//       (contribution.value >= _minContribution.value &&
//         contribution.token == _minContribution.token) || _minContribution.value == 0 // TODO: should probably consider _maxSupply too
//     ) {
//       uint256 tokenId = _supply;
//       _mint(account, tokenId);

//       _supply += 1;
//     }
//   }
// }
