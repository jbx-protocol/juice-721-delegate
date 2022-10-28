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
    @param _amountToDelegateToSelf The amount to delegate to this contract, which is a pay delegate that'll be included.
  */
  function _initialize(
    JBPayDelegateAllocation[] memory __delegateAllocations,
    uint256 _amountToDelegateToSelf
  ) internal {
    // Keep a reference to the number of delegate allocations being added.
    uint256 _numberOfDelegateAlloctions = __delegateAllocations.length;

    // Add each delegate allocations to storage.
    for (uint256 _i; _i < _numberOfDelegateAlloctions; ) {
      _delegateAllocations[_i] = __delegateAllocations[_i];
      unchecked {
        ++_i;
      }
    }

    // Push this contract onto the list of delegates.
    _delegateAllocations.push(JBPayDelegateAllocation(this, _amountToDelegateToSelf));
  }
}
