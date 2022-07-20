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
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.
    @param _launchProjectData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return projectId The ID of the newly configured project.
  */
  function launchProjectFor(
    address _owner,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBLaunchProjectData memory _launchProjectData
  ) external override returns (uint256 projectId) {
    // Get the project ID, optimistically knowing it will be one greater than the current count.
    projectId = controller.projects().count() + 1;

    // Deploy the data source contract.
    address _dataSourceAddress = deployDataSource(projectId, _deployTieredNFTRewardDataSourceData);

    // Set the data source address as the data source of the provided metadata.
    _launchProjectData.metadata.dataSource = _dataSourceAddress;

    // Launch the project.
    _launchProjectFor(_owner, _launchProjectData);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    Deploys a Tiered limited NFT reward data source.

    @param _projectId The ID of the project for which the data source should apply.
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.

    @return newDatasource The address of the newly deployed data source.
  */
  function deployDataSource(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData
  ) public override returns (address newDatasource) {
    newDatasource = address(
      new JBTieredLimitedNFTRewardDataSource(
        _projectId,
        _deployTieredNFTRewardDataSourceData.directory,
        _deployTieredNFTRewardDataSourceData.name,
        _deployTieredNFTRewardDataSourceData.symbol,
        _deployTieredNFTRewardDataSourceData.tokenUriResolver,
        _deployTieredNFTRewardDataSourceData.contractUri,
        _deployTieredNFTRewardDataSourceData.owner,
        _deployTieredNFTRewardDataSourceData.tiers,
        _deployTieredNFTRewardDataSourceData.shouldMintByDefault
      )
    );

    emit DatasourceDeployed(_projectId, newDatasource);
  }

  /** 
    @notice
    Launches funding cycles for a project.

    @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    @param _launchProjectData Data necessary to fulfill the transaction to launch the project.
  */
  function _launchProjectFor(address _owner, JBLaunchProjectData memory _launchProjectData)
    internal
  {
    controller.launchProjectFor(
      _owner,
      _launchProjectData.projectMetadata,
      _launchProjectData.data,
      _launchProjectData.metadata,
      _launchProjectData.mustStartAtOrAfter,
      _launchProjectData.groupedSplits,
      _launchProjectData.fundAccessConstraints,
      _launchProjectData.terminals,
      _launchProjectData.memo
    );
  }
}
