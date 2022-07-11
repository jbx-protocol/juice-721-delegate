// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/**
  @dev 
  Token id 0 has special meaning in NFTRewardDataSourceDelegate where minting will be skipped.

  @dev 
  An example tier collecting might look like this:
  [ { contributionFloor: 1 ether, idCeiling: 1001, remainingAllowance: 1000, initialAllowance: 1000 }, { contributionFloor: 5 ether, idCeiling: 1501, remainingAllowance: 500, initialAllowance: 500 }, { contributionFloor: 10 ether, idCeiling: 1511, remainingAllowance: 10, initialAllowance: 10 }]

  @member contributionFloor The minimum contribution to qualify for this tier.
  @member idCeiling The highest token ID in this tier.
  @member remainingAllowance Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
  @member initialAllowance The initial `remainingAllowance` value when the tier was set.
  @member baseUri The tokenUri for the tier.
*/
struct JBNFTRewardTier {
  uint128 contributionFloor;
  uint48 idCeiling;
  uint40 remainingAllowance;
  uint40 initialAllowance;
  string baseUri;
}
