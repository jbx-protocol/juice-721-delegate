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
  Deploys a tier delegate.

  @dev
  Adheres to -
  IJBTiered721DelegateDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.
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
    Deploys a delegate.

    @param _projectId The ID of the project this contract's functionality applies to.
    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.

    @return newDataSource The address of the newly deployed data source.
  */
  function deployDataSourceFor(
    uint256 _projectId,
    JBDeployTiered721DelegateData memory _deployTiered721DelegateData
  ) external override returns (IJBTiered721Delegate) {
    // Deploy the delegate contract.
    JBTiered721Delegate newDataSource = new JBTiered721Delegate(
      _projectId,
      _deployTiered721DelegateData.directory,
      _deployTiered721DelegateData.name,
      _deployTiered721DelegateData.symbol,
      _deployTiered721DelegateData.baseUri,
      _deployTiered721DelegateData.tokenUriResolver,
      _deployTiered721DelegateData.contractUri,
      _deployTiered721DelegateData.tiers,
      _deployTiered721DelegateData.store,
      _deployTiered721DelegateData.lockReservedTokenChanges,
      _deployTiered721DelegateData.lockVotingUnitChanges
    );

    // Transfer the ownership to the specified address.
    if (_deployTiered721DelegateData.owner != address(0))
      newDataSource.transferOwnership(_deployTiered721DelegateData.owner);

    emit DatasourceDeployed(_projectId, newDataSource);

    return newDataSource;
  }
}
