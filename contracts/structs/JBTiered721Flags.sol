// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** 
  @member lockReservedTokenChanges A flag indicating if reserved tokens can change over time by adding new tiers with a reserved rate.
  @member lockVotingUnitChanges A flag indicating if minting reserved tokens is paused during the current funding cycle.
*/
struct JBTiered721Flags {
  bool lockReservedTokenChanges;
  bool lockVotingUnitChanges;
}
