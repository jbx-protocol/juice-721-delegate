// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import './JBTiered721Delegate.sol';
import './interfaces/IJBTiered721DelegateDeployer.sol';

/**
  @notice
  Deploys a project with a tiered limited NFT reward data source attached.

  @dev
  Adheres to -
  IJBTiered721DelegateProjectDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.

  @dev
  Inherits from -
  JBOperatable: Several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
*/
contract JBTiered721DelegateDeployer is IJBTiered721DelegateDeployer {
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
    JBDeployTiered721DelegateData memory _deployTieredNFTRewardDataSourceData
  ) external override returns (IJBTiered721Delegate) {
    JBTiered721Delegate newDataSource = new JBTiered721Delegate(
      _projectId,
      _deployTieredNFTRewardDataSourceData.directory,
      _deployTieredNFTRewardDataSourceData.name,
      _deployTieredNFTRewardDataSourceData.symbol,
      _deployTieredNFTRewardDataSourceData.baseUri,
      _deployTieredNFTRewardDataSourceData.tokenUriResolver,
      _deployTieredNFTRewardDataSourceData.contractUri,
      _deployTieredNFTRewardDataSourceData.tiers,
      _deployTieredNFTRewardDataSourceData.store,
      _deployTieredNFTRewardDataSourceData.lockReservedTokenChanges,
      _deployTieredNFTRewardDataSourceData.lockVotingUnitChanges
    );

    // Transfer the ownership to the specified address.
    if (_deployTieredNFTRewardDataSourceData.owner != address(0))
      newDataSource.transferOwnership(_deployTieredNFTRewardDataSourceData.owner);

    emit DatasourceDeployed(_projectId, newDataSource);

    return newDataSource;
  }
}
