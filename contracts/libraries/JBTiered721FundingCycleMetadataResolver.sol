// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import './../structs/JBTiered721FundingCycleMetadata.sol';

library JBTiered721FundingCycleMetadataResolver {
  function transfersPaused(uint256 _data) internal pure returns (bool) {
    return (_data & 1) == 1;
  }

  function mintingReservesPaused(uint256 _data) internal pure returns (bool) {
    return ((_data >> 1) & 1) == 1;
  }

  function changingPricingResolverPaused(uint256 _data) internal pure returns (bool) {
    return ((_data >> 2) & 1) == 1;
  }
}
