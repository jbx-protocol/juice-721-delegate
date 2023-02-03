// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import './JB721SplitOrder.sol';

/**
  @member amount The amount to split.
  @member splitOrders A group of split orders.
*/
struct JB721SplitOrders {
  uint256 amount;
  JB721SplitOrder[] orders;
}
