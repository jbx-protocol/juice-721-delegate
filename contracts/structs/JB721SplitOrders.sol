// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import './JB721SplitOrder.sol';

/**
  @member totalValue The total value to split across all orders.
  @member splitOrders A group of split orders.
*/
struct JB721SplitOrders {
  uint256 totalValue;
  JB721SplitOrder[] orders;
}
