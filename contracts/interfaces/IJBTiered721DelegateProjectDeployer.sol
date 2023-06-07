// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController3_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol";
import "../structs/JBDeployTiered721DelegateData.sol";
import "../structs/JBLaunchProjectData.sol";
import "../structs/JBLaunchFundingCyclesData.sol";
import "../structs/JBReconfigureFundingCyclesData.sol";
import "./IJBTiered721DelegateDeployer.sol";

interface IJBTiered721DelegateProjectDeployer {
    function directory() external view returns (IJBDirectory);

    function delegateDeployer() external view returns (IJBTiered721DelegateDeployer);

    function launchProjectFor(
        address owner,
        JBDeployTiered721DelegateData memory deployTiered721DelegateData,
        JBLaunchProjectData memory launchProjectData,
        IJBController3_1 controller
    ) external returns (uint256 projectId);

    function launchFundingCyclesFor(
        uint256 projectId,
        JBDeployTiered721DelegateData memory deployTiered721DelegateData,
        JBLaunchFundingCyclesData memory launchFundingCyclesData,
        IJBController3_1 controller
    ) external returns (uint256 configuration);

    function reconfigureFundingCyclesOf(
        uint256 projectId,
        JBDeployTiered721DelegateData memory deployTiered721DelegateData,
        JBReconfigureFundingCyclesData memory reconfigureFundingCyclesData,
        IJBController3_1 controller
    ) external returns (uint256 configuration);
}
