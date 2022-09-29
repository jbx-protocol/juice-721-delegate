// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBTokenAmount.sol';

interface IJB721PricingResolver is IERC165 {
  function valueOf(
    JBTokenAmount calldata _amount,
    address _beneficiary,
    uint256 _targetCurrency,
    uint256 _targetDecimals
  ) external returns (uint256);
}
