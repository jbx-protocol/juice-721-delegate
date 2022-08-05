// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import './JBTieredLimitedNFTRewardDataSource.sol';
import './interfaces/IJBTieredLimitedNFTRewardDataSourceDeployer.sol';

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
contract JBTieredLimitedNFTRewardDataSourceDeployer is IJBTieredLimitedNFTRewardDataSourceDeployer {
  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  constructor() {}

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Deploys a Tiered limited NFT reward data source.

    @param _projectId The ID of the project for which the data source should apply.
    @param _deployTieredNFTRewardDataSourceData Data necessary to fulfill the transaction to deploy a tiered limited NFT rewward data source.

    @return newDataSource The address of the newly deployed data source.
  */
  function deployDataSourceFor(
    uint256 _projectId,
    JBDeployTieredNFTRewardDataSourceData memory _deployTieredNFTRewardDataSourceData
  ) external override returns (address newDataSource) {
    newDataSource = address(
      new JBTieredLimitedNFTRewardDataSource(
        _projectId,
        _deployTieredNFTRewardDataSourceData.directory,
        _deployTieredNFTRewardDataSourceData.name,
        _deployTieredNFTRewardDataSourceData.symbol,
        _deployTieredNFTRewardDataSourceData.baseUri,
        _deployTieredNFTRewardDataSourceData.tokenUriResolver,
        _deployTieredNFTRewardDataSourceData.contractUri,
        _deployTieredNFTRewardDataSourceData.owner,
        _deployTieredNFTRewardDataSourceData.tierData,
        _deployTieredNFTRewardDataSourceData.store
      )
    );

    emit DatasourceDeployed(_projectId, newDataSource);
  }
}
