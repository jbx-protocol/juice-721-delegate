// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JBNFTRewardTierData.sol';

/**
  @member id The tier's ID.
  @member data The data describing the tier's properties.
*/
struct JBNFTRewardTier {
  uint256 id;
  JBNFTRewardTierData data;
}
