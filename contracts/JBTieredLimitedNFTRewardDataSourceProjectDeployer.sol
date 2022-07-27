// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import './JBTieredLimitedNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';

/**
  @notice
  Deploys a project with a tiered limited NFT reward data source attached.

  @dev
  Adheres to -
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.

  @dev
  Inherits from -
  JBOperatable: Several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
*/
contract JBTieredLimitedNFTRewardDataSourceProjectDeployer is
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer,
  JBOperatable
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
    @param _operatorStore A contract storing operator assignments.
  */
  constructor(IJBController _controller, IJBOperatorStore _operatorStore)
    JBOperatable(_operatorStore)
  {
    controller = _controller;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice 
    Launches a new project with a tiered NFT rewards data source attached.

    @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.
    @param _launchProjectData Data necessary to fulfill the transaction to launch a project.

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

    // Set the project to use the data source for it's pay function.
    _launchProjectData.metadata.useDataSourceForPay = true;

    // Launch the project.
    _launchProjectFor(_owner, _launchProjectData);
  }

  /** 
    @notice 
    Launches funding cycle's for a project with a tiered NFT rewards data source attached.

    @dev
    Only a project owner or operator can launch its funding cycles.

    @param _projectId The ID of the project having funding cycles launched. 
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully created.  
  */
  function launchFundingCyclesFor(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBLaunchFundingCyclesData memory _launchFundingCyclesData
  )
    external
    override
    requirePermission(
      controller.projects().ownerOf(_projectId),
      _projectId,
      JBOperations.RECONFIGURE
    )
    returns (uint256 configuration)
  {
    // Deploy the data source contract.
    address _dataSourceAddress = deployDataSource(_projectId, _deployTieredNFTRewardDataSourceData);

    // Set the data source address as the data source of the provided metadata.
    _launchFundingCyclesData.metadata.dataSource = _dataSourceAddress;

    // Set the project to use the data source for it's pay function.
    _launchFundingCyclesData.metadata.useDataSourceForPay = true;

    // Launch the funding cycles.
    return _launchFundingCyclesFor(_projectId, _launchFundingCyclesData);
  }

  /** 
    @notice 
    Reconfigures funding cycles for a project with a tiered NFT rewards data source attached.

    @dev
    Only a project's owner or a designated operator can configure its funding cycles.

    @param _projectId The ID of the project having funding cycles launched. 
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.
    @param _reconfigureFundingCyclesData Data necessary to fulfill the transaction to reconfigure funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function reconfigureFundingCyclesOf(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData,
    JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
  )
    external
    override
    requirePermission(
      controller.projects().ownerOf(_projectId),
      _projectId,
      JBOperations.RECONFIGURE
    )
    returns (uint256 configuration)
  {
    // Deploy the data source contract.
    address _dataSourceAddress = deployDataSource(_projectId, _deployTieredNFTRewardDataSourceData);

    // Set the data source address as the data source of the provided metadata.
    _reconfigureFundingCyclesData.metadata.dataSource = _dataSourceAddress;

    // Set the project to use the data source for it's pay function.
    _reconfigureFundingCyclesData.metadata.useDataSourceForPay = true;

    // Reconfigure the funding cycles.
    return _reconfigureFundingCyclesOf(_projectId, _reconfigureFundingCyclesData);
  }

  //*********************************************************************//
  // ----------------------- public transactions ----------------------- //
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
        _deployTieredNFTRewardDataSourceData.baseUri,
        _deployTieredNFTRewardDataSourceData.owner,
        _deployTieredNFTRewardDataSourceData.tierData,
        _deployTieredNFTRewardDataSourceData.shouldMintByDefault,
        _deployTieredNFTRewardDataSourceData.reservedTokenBeneficiary
      )
    );

    emit DatasourceDeployed(_projectId, newDatasource);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    Launches a project.

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

  /** 
    @notice
    Launches funding cycles for a project.

    @param _projectId The ID of the project having funding cycles launched. 
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully created.  
  */
  function _launchFundingCyclesFor(
    uint256 _projectId,
    JBLaunchFundingCyclesData memory _launchFundingCyclesData
  ) internal returns (uint256) {
    return
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

  /** 
    @notice
    Reconfigure funding cycles for a project.

    @param _projectId The ID of the project having funding cycles launched. 
    @param _reconfigureFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return The configuration of the funding cycle that was successfully reconfigured.
  */
  function _reconfigureFundingCyclesOf(
    uint256 _projectId,
    JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
  ) internal returns (uint256) {
    return
      controller.reconfigureFundingCyclesOf(
        _projectId,
        _reconfigureFundingCyclesData.data,
        _reconfigureFundingCyclesData.metadata,
        _reconfigureFundingCyclesData.mustStartAtOrAfter,
        _reconfigureFundingCyclesData.groupedSplits,
        _reconfigureFundingCyclesData.fundAccessConstraints,
        _reconfigureFundingCyclesData.memo
      );
  }
}
