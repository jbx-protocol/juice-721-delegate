// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBProjectMetadata.sol';
import '../structs/JBDeployTieredNFTRewardDataSourceData.sol';
import '../structs/JBLaunchProjectData.sol';
import '../structs/JBLaunchFundingCyclesData.sol';
import '../structs/JBReconfigureFundingCyclesData.sol';

interface IJBTieredLimitedNFTRewardDataSourceDeployer {
  event DatasourceDeployed(uint256 indexed projectId, address newDatasource);

  function deployDataSourceFor(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData
  ) external returns (address dataSource);
}
