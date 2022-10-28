// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayDelegate.sol';
import '../interfaces/IJBDelegateSource.sol';

abstract contract JBDelegateSource is IJBDelegateSource, IJBPayDelegate {
  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /**
    @notice
    The allocations to delegates from this data source.
  */
  JBPayDelegateAllocation[] internal _delegateAllocations;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /**
    @notice 
    The allocations to delegates from this data source.

    @return The delegateallocations.
  */
  function delegateAllocations() external view override returns (JBPayDelegateAllocation[] memory) {
    return _delegateAllocations;
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param __delegateAllocations The delegate allocations to include.
  */
  function _initialize(JBPayDelegateAllocation[] memory __delegateAllocations) internal {
    uint256 _numberOfDelegateAlloctions = __delegateAllocations.length;
    for (uint256 _i; _i < _numberOfDelegateAlloctions; ) {
      _delegateAllocations[_i] = __delegateAllocations[_i];
      unchecked {
        ++_i;
      }
    }
    _delegateAllocations.push(JBPayDelegateAllocation(this, 0));
  }
}
