// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplit.sol';

/**
  @member value The value to split.
  @member splits A group of splits to route funds to.
*/
struct JB721SplitOrder {
  uint256 value;
  JBSplit[] splits;
}