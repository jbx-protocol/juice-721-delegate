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
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//
  JB721GlobalGovernance immutable globalGovernance;
  JB721TieredGovernance immutable tieredGovernance;
  JBTiered721Delegate immutable noGovernance;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  constructor(
    JB721GlobalGovernance _globalGovernance,
    JB721TieredGovernance _tieredGovernance,
    JBTiered721Delegate _noGovernance
  ) {
    globalGovernance = _globalGovernance;
    tieredGovernance = _tieredGovernance;
    noGovernance = _noGovernance;
  }

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
    address codeToCopy;
    if (_deployTiered721DelegateData.governanceType == GovernanceType.NONE) {
      codeToCopy = address(noGovernance);
    } else if (_deployTiered721DelegateData.governanceType == GovernanceType.TIERED) {
      codeToCopy = address(tieredGovernance);
    } else if (_deployTiered721DelegateData.governanceType == GovernanceType.GLOBAL) {
      codeToCopy = address(globalGovernance);
    } else {
      revert INVALID_GOVERNANCE_TYPE();
    }

    JB721GlobalGovernance newDelegate = JB721GlobalGovernance(_clone(codeToCopy));
    newDelegate.initialize(
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

    // Transfer the ownership to the specified address.
    if (_deployTiered721DelegateData.owner != address(0))
      newDelegate.transferOwnership(_deployTiered721DelegateData.owner);

    emit DelegateDeployed(_projectId, newDelegate, _deployTiered721DelegateData.governanceType);

    return newDelegate;
  }

  // https://github.com/drgorillamd/clone-deployed-contract
  function _clone(address _targetAddress) internal returns (address _out) {
    bytes32 _dump;
    assembly {
      // Retrieve target address
      //let _targetAddress := sload(_target.slot)

      // Get deployed code size
      let _codeSize := extcodesize(_targetAddress)

      // Get a bit of freemem to land the bytecode
      let _freeMem := mload(0x40)

      // Shift the length to the length placeholder
      let _mask := mul(_codeSize, 0x100000000000000000000000000000000000000000000000000000000)

      // I built the init by hand (and it was quite fun)
      let _initCode := or(_mask, 0x620000006100118181600039816000f3fe000000000000000000000000000000)

      mstore(_freeMem, _initCode)

      // Copy the bytecode (our initialise part is 17 bytes long)
      extcodecopy(_targetAddress, add(_freeMem, 17), 0, _codeSize)

      _dump := mload(_freeMem)

      // Deploy the copied bytecode
      _out := create(0, _freeMem, _codeSize)

      // We're tidy people, we update our freemem ptr + 64bytes for the padding - yes, ugly
      mstore(0x40, add(_freeMem, add(_codeSize, 64)))
    }
  }
}
