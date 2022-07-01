// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IToken721UriResolver.sol';
import './ITokenSupplyDetails.sol';
import './../structs/JBNFTRewardTier.sol';

interface IJBTieredNFTRewardDelegate is ITokenSupplyDetails {
  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tier,
    address indexed beneficiary,
    uint256 value,
    address caller
  );

  event Burn(uint256 indexed tokenId, address owner, address caller);

  function tiers() external view returns (JBNFTRewardTier[] memory);

  function contributionToken() external view returns (address);

  function tierNumberOfToken(uint256 _tokenId) external view returns (uint256);

  function mint(address _beneficiary, uint256 _value) external returns (uint256 tokenId);

  function burn(address _owner, uint256 _tokenId) external;
}
