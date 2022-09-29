// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPrices.sol';
import './../interfaces/IJB721ValueResolver.sol';
import './JB721TierParams.sol';

/**
  @member tiers The tiers to set.
  @member currency The currency that the tier contribution floors are denoted in.
  @member decimals The number of decimals included in the tier contribution floor fixed point numbers.
  @member prices A contract that exposes price feeds that can be used to resolved the value of a contributions that are sent in different currencies. Set to the zero address if payments must be made in `currency`.
  @member resolver A contract that can be used to return custom prices. Overwrites the `prices` contract and the default 1:1 acceptance of payments made in the same currency as expected.
*/
struct JB721PricingParams {
  JB721TierParams[] tiers;
  uint256 currency;
  uint256 decimals;
  IJBPrices prices;
  IJB721ValueResolver resolver;
}
