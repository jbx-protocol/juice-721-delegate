// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member remainingQuantity Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member tokenUribaseUri The URI to use for each token within the tier.
*/
struct JBNFTRewardTier {
  uint128 contributionFloor;
  uint64 remainingQuantity;
  uint64 initialQuantity;
  string tokenUri;
}
