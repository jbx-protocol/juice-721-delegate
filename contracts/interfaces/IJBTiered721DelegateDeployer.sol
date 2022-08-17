// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBProjectMetadata.sol';
import '../structs/JBDeployTiered721DelegateData.sol';
import '../structs/JBLaunchProjectData.sol';
import '../structs/JBLaunchFundingCyclesData.sol';
import '../structs/JBReconfigureFundingCyclesData.sol';
import './IJBTiered721Delegate.sol';

interface IJBTiered721DelegateDeployer {
  event DelegateDeployed(uint256 indexed projectId, IJBTiered721Delegate newDatasource);

  function deployDelegateFor(
    uint256 _projectId,
    JBDeployTiered721DelegateData memory _deployTieredNFTRewardDataSourceData
  ) external returns (IJBTiered721Delegate dataSource);
}
