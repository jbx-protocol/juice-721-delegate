// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import './JBTieredLimitedNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';

/**
  @notice
  Deploys a project with a tiered limited NFT reward data source attached.
*/
contract JBTieredLimitedNFTRewardDataSourceProjectDeployer is
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer
{
  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /** 
    @notice
    The controller with which new projects should be deployed. 
  */
  IJBController public immutable override controller;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /** 
    @param _controller The controller with which new projects should be deployed. 
  */
  constructor(IJBController _controller) {
    controller = _controller;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice 
    Launches a new project with a tiered NFT rewards data source attached.

    @dev
    This contract must have operator permission for the `RECONFIGURE` index (1) over the `_owner` account.

    @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    @param _projectMetadata Metadata to associate with the project within a particular domain. This can be updated any time by the owner of the project.
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return projectId The ID of the newly configured project.
  */
  function launchProject(
    address _owner,
    JBProjectMetadata memory _projectMetadata,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBLauchFundingCyclesData memory _launchFundingCyclesData
  ) external override returns (uint256 projectId) {
    // Launch the project.
    projectId = controller.projects().createFor(_owner, _projectMetadata);

    // Deploy the data source contract.
    address _dataSourceAddress = _deployDataSource(projectId, _deployTieredNFTRewardDataSourceData);

    // Set the data source address as the data source of the provided metadata.
    _launchFundingCyclesData.metadata.dataSource = _dataSourceAddress;

    // Launch funding cycles for the project.
    _launchFundingCycles(projectId, _launchFundingCyclesData);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    Deploys a Tiered limited NFT reward data source.

    @param _projectId The ID of the project for which the data source should apply.
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.

    @return The address of the newly deployed data source.
  */
  function _deployDataSource(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData
  ) internal returns (address) {
    return
      address(
        new JBTieredLimitedNFTRewardDataSource(
          _projectId,
          _deployTieredNFTRewardDataSourceData.directory,
          _deployTieredNFTRewardDataSourceData.name,
          _deployTieredNFTRewardDataSourceData.symbol,
          _deployTieredNFTRewardDataSourceData.tokenUriResolver,
          _deployTieredNFTRewardDataSourceData.baseUri,
          _deployTieredNFTRewardDataSourceData.contractUri,
          _deployTieredNFTRewardDataSourceData.expectedCaller,
          _deployTieredNFTRewardDataSourceData.owner,
          _deployTieredNFTRewardDataSourceData.contributionToken,
          _deployTieredNFTRewardDataSourceData.tiers
        )
      );
  }

  /** 
    @notice
    Launches funding cycles for a project.

    @param _projectId The ID of the project for which funding cycles are being launched.
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.
  */
  function _launchFundingCycles(
    uint256 _projectId,
    JBLauchFundingCyclesData memory _launchFundingCyclesData
  ) internal {
    controller.launchFundingCyclesFor(
      _projectId,
      _launchFundingCyclesData.data,
      _launchFundingCyclesData.metadata,
      _launchFundingCyclesData.mustStartAtOrAfter,
      _launchFundingCyclesData.groupedSplits,
      _launchFundingCyclesData.fundAccessConstraints,
      _launchFundingCyclesData.terminals,
      _launchFundingCyclesData.memo
    );
  }
}
