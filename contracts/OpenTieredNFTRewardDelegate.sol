// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './abstract/AbstractNFTRewardDelegate.sol';

/**
  @dev Token id 0 has special meaning in NFTRewardDataSourceDelegate where minting will be skipped.
  @dev An example tier collecting might look like this:
  [ { contributionFloor: 1 ether }, { contributionFloor: 5 ether }, { contributionFloor: 10 ether } ]
 */
struct OpenRewardTier {
  /** @notice Minimum contribution to qualify for this tier. */
  uint256 contributionFloor;
}

//*********************************************************************//
// --------------------------- custom errors ------------------------- //
//*********************************************************************//
error INVALID_PRICE_SORT_ORDER(uint256);
error INVALID_ID_SORT_ORDER(uint256);

/**
  @title Juicebox data source delegate that offers project contributors NFTs.

  @notice This contract allows project creators to reward contributors with NFTs. Intended use is to incentivize initial project support by minting a limited number of NFTs to the first N contributors.

  @notice One use case is enabling the project to mint an NFT for anyone contributing any amount without a mint limit. Set minContribution.value to 0 and maxSupply to uint256.max to do this. To mint NFTs to the first 100 participants contributing 1000 DAI or more, set minContribution.value to 1000000000000000000000 (3 + 18 zeros), minContribution.token to 0x6B175474E89094C44Da98b954EedeAC495271d0F and maxSupply to 100.

  @dev Keep in mind that this PayDelegate and RedeemDelegate implementation will simply pass through the weight and reclaimAmount it is called with.
 */
contract OpenTieredNFTRewardDelegate is AbstractNFTRewardDelegate {
  address public contributionToken;
  OpenRewardTier[] public tiers;

  /**
    @notice This price resolver allows project admins to define multiple reward tiers for contributions and issue NFTs to people who contribute at those levels. 

    @dev This pride resolver requires a custom token uri resolver which is defined in OpenTieredTokenUriResolver.

    @dev Tiers list must be sorted by floor otherwise contributors won't be rewarded properly.

    @dev There is a limit of 255 tiers.

    @param _contributionToken Token used for contributions, use JBTokens.ETH to specify ether.
    @param _tiers Sorted tier collection.
   */
  constructor(
    uint256 projectId,
    IJBDirectory directory,
    uint256 maxSupply,
    string memory _name,
    string memory _symbol,
    string memory _uri,
    IToken721UriResolver _tokenUriResolverAddress,
    string memory _contractMetadataUri,
    address _admin,
    address _contributionToken,
    OpenRewardTier[] memory _tiers
  )
    AbstractNFTRewardDelegate(
      projectId,
      directory,
      maxSupply,
      _name,
      _symbol,
      _uri,
      _tokenUriResolverAddress,
      _contractMetadataUri,
      _admin
    )
  {
    contributionToken = _contributionToken;

    if (_tiers.length > type(uint8).max) {
      revert();
    }

    if (_tiers.length > 0) {
      tiers.push(_tiers[0]);
      for (uint256 i = 1; i < _tiers.length; i++) {
        if (_tiers[i].contributionFloor < _tiers[i - 1].contributionFloor) {
          revert INVALID_PRICE_SORT_ORDER(i);
        }

        tiers.push(_tiers[i]);
      }
    }
  }

  /**
    @notice Mints a token for a given contribution for the contributor account.

    @param account Address sending the contribution.
    @param contribution Contribution amount.
   */
  function validateContribution(address account, JBTokenAmount calldata contribution)
    internal
    override
  {
    if (contribution.token != contributionToken) {
      return;
    }

    uint256 tokenId;
    for (uint256 i; i < tiers.length; i++) {
      if (
        (tiers[i].contributionFloor <= contribution.value && i == tiers.length - 1) ||
        (tiers[i].contributionFloor <= contribution.value &&
          tiers[i + 1].contributionFloor > contribution.value)
      ) {
        tokenId = i | (uint248(uint256(keccak256(abi.encodePacked(account, block.number)))) << 8);
        break;
      }
    }

    if (tokenId != 0) {
      _mint(account, tokenId);

      _supply += 1;
    }
  }
}
