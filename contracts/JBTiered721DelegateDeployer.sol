// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol';
import './JBTiered721Delegate.sol';
import './JB721TieredGovernance.sol';
import './JB721GlobalGovernance.sol';
import './interfaces/IJBTiered721DelegateDeployer.sol';

/**
  @notice
  Deploys a tier delegate.

  @dev
  Adheres to -
  IJBTiered721DelegateDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.
*/
contract JBTiered721DelegateDeployer is IJBTiered721DelegateDeployer {

  error INVALID_GOVERNANCE_TYPE();

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

    @return newDelegate The address of the newly deployed delegate.
  */
  function deployDelegateFor(
    uint256 _projectId,
    JBDeployTiered721DelegateData memory _deployTiered721DelegateData
  ) external override returns (IJBTiered721Delegate) {

    // Deploy the governance variant that was requested
    JBTiered721Delegate newDelegate;
    if (_deployTiered721DelegateData.governanceType == GovernanceType.NONE) {
      // Deploy the delegate contract.
       newDelegate = new JBTiered721Delegate(
        _projectId,
        _deployTiered721DelegateData.directory,
        _deployTiered721DelegateData.name,
        _deployTiered721DelegateData.symbol,
        _deployTiered721DelegateData.fundingCycleStore,
        _deployTiered721DelegateData.baseUri,
        _deployTiered721DelegateData.tokenUriResolver,
        _deployTiered721DelegateData.contractUri,
        _deployTiered721DelegateData.pricing,
        _deployTiered721DelegateData.store,
        _deployTiered721DelegateData.flags
      );
    }else if (_deployTiered721DelegateData.governanceType == GovernanceType.TIERED) {
      // Deploy the delegate contract.
      newDelegate = new JB721TieredGovernance(
        _projectId,
        _deployTiered721DelegateData.directory,
        _deployTiered721DelegateData.name,
        _deployTiered721DelegateData.symbol,
        _deployTiered721DelegateData.fundingCycleStore,
        _deployTiered721DelegateData.baseUri,
        _deployTiered721DelegateData.tokenUriResolver,
        _deployTiered721DelegateData.contractUri,
        _deployTiered721DelegateData.pricing,
        _deployTiered721DelegateData.store,
        _deployTiered721DelegateData.flags
      );
    }else if (_deployTiered721DelegateData.governanceType == GovernanceType.GLOBAL){
      // Deploy the delegate contract.
      newDelegate = new JB721GlobalGovernance(
        _projectId,
        _deployTiered721DelegateData.directory,
        _deployTiered721DelegateData.name,
        _deployTiered721DelegateData.symbol,
        _deployTiered721DelegateData.fundingCycleStore,
        _deployTiered721DelegateData.baseUri,
        _deployTiered721DelegateData.tokenUriResolver,
        _deployTiered721DelegateData.contractUri,
        _deployTiered721DelegateData.pricing,
        _deployTiered721DelegateData.store,
        _deployTiered721DelegateData.flags
      );
    }else{
      revert INVALID_GOVERNANCE_TYPE();
    }
    

    // Transfer the ownership to the specified address.
    if (_deployTiered721DelegateData.owner != address(0))
      newDelegate.transferOwnership(_deployTiered721DelegateData.owner);

    emit DelegateDeployed(_projectId, newDelegate, _deployTiered721DelegateData.governanceType);

    return newDelegate;
  }
}
