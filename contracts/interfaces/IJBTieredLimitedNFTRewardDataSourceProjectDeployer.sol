// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/structs/JBProjectMetadata.sol';
import '../structs/JBDeployTieredNFTRewardDataSourceData.sol';
import '../structs/JBLauchFundingCyclesData.sol';

interface IJBTieredLimitedNFTRewardDataSourceProjectDeployer {
  function controller() external view returns (IJBController);

  function launchProject(
    address _owner,
    JBProjectMetadata memory _projectMetadata,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBLauchFundingCyclesData memory _launchFundingCyclesData
  ) external returns (uint256 projectId);
}
