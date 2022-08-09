// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed or paused.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @memver reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member reservedRateBeneficiary The beneificary of the reserved tokens for this tier.
  @member encodedIPFSUri The URI to use for each token within the tier.
  @member shouldUseBeneficiaryAsDefault A flag indicating if the `reservedTokenBeneficiary` should be stored as the default beneficiary for all tiers.
*/
struct JB721TierParams {
  uint256 contributionFloor;
  uint256 lockedUntil;
  uint256 initialQuantity;
  uint256 votingUnits;
  uint256 reservedRate;
  address reservedTokenBeneficiary;
  bytes32 encodedIPFSUri;
  bool shouldUseBeneficiaryAsDefault;
}
