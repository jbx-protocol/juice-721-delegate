// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './JB721TierData.sol';

/**
  @member id The tier's ID.
  @member data The data describing the tier's properties.
*/
struct JB721Tier {
  uint256 id;
  JB721TierData data;
}
