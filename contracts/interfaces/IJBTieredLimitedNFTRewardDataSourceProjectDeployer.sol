// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBProjectMetadata.sol';
import '../structs/JBDeployTieredNFTRewardDataSourceData.sol';
import '../structs/JBLaunchProjectData.sol';

interface IJBTieredLimitedNFTRewardDataSourceProjectDeployer {
  event DatasourceDeployed(uint256 indexed projectId, address newDatasource);

  function controller() external view returns (IJBController);

  function launchProjectFor(
    address _owner,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBLaunchProjectData memory _launchProjectData
  ) external returns (uint256 projectId);

  function deployDataSource(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData
  ) external returns (address dataSource);
}
