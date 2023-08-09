// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";

interface IJB721Delegate {
    function projectId() external view returns (uint256);

    function directory() external view returns (IJBDirectory);

    function payMetadataDelegateId() external view returns (bytes4);

    function redeemMetadataDelegateId() external view returns (bytes4);
}
