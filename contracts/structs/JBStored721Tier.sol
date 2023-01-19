// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed or paused.
  @member remainingQuantity Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @member reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member royaltyRate The percentage of each of the NFT sales that should be routed to the royalty beneficiary. Out of MAX_ROYALTY_RATE.
  @member allowManualMint A flag indicating if the contract's owner can mint from this tier on demand.
  @member transfersPausable A flag indicating if transfers from this tier can be pausable. 
*/
struct JBStored721Tier {
  uint80 contributionFloor;
  uint48 lockedUntil;
  uint40 remainingQuantity;
  uint40 initialQuantity;
  uint16 votingUnits;
  uint16 reservedRate;
  uint8 royaltyRate;
  bool allowManualMint;
  bool transfersPausable;
}
