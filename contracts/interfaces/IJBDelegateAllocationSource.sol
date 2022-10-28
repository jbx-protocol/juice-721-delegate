// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayDelegateAllocation.sol';

interface IJBDelegateAllocationSource {
  function delegateAllocations() external view returns (JBPayDelegateAllocation[] memory);
}
