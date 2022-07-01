// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IToken721UriResolver.sol';
import './ITokenSupplyDetails.sol';
import './../structs/JBNFTRewardTier.sol';

interface IJBTieredNFTRewardDelegate is ITokenSupplyDetails {
  function tiers() external view returns (JBNFTRewardTier[] memory);

  function contributionToken() external view returns (address);

  function tierSupply(uint256 _tierNumber) external view returns (uint256);
}
