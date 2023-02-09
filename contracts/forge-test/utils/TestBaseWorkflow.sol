// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/JBController3_1.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBDirectory.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBETHPaymentTerminal.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBERC20PaymentTerminal.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBSingleTokenPaymentTerminalStore3_1.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBFundingCycleStore.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBOperatorStore.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBPrices.sol';
import {JBProjects} from '@jbx-protocol/juice-contracts-v3/contracts/JBProjects.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBSplitsStore.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBToken.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/JBTokenStore.sol';

import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFee.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBGroupedSplits.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBOperatorData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayParamsData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplit.sol';

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBToken.sol';

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBFundingCycleMetadataResolver.sol';

import '@paulrberg/contracts/math/PRBMath.sol';

import 'forge-std/Test.sol';

import './AccessJBLib.sol';

import './../../structs/JBPayDataSourceFundingCycleMetadata.sol';

// Base contract for Juicebox system tests.
//
// Provides common functionality, such as deploying contracts on test setup.
contract TestBaseWorkflow is Test {
  //*********************************************************************//
  // --------------------- internal stored properties ------------------- //
  //*********************************************************************//

  address internal _projectOwner = address(123);
  address internal _beneficiary = address(69420);
  address internal _caller = address(696969);

  JBOperatorStore internal _jbOperatorStore;
  JBProjects internal _jbProjects;
  JBPrices internal _jbPrices;
  JBDirectory internal _jbDirectory;
  JBFundingCycleStore internal _jbFundingCycleStore;
  JBTokenStore internal _jbTokenStore;
  JBSplitsStore internal _jbSplitsStore;
  JBController3_1 internal _jbController;
  JBSingleTokenPaymentTerminalStore3_1 internal _jbPaymentTerminalStore;
  JBETHPaymentTerminal internal _jbETHPaymentTerminal;
  JBProjectMetadata internal _projectMetadata;
  JBFundingCycleData internal _data;
  JBPayDataSourceFundingCycleMetadata internal _metadata;
  JBGroupedSplits[] internal _groupedSplits;
  JBFundAccessConstraints[] internal _fundAccessConstraints;
  IJBPaymentTerminal[] internal _terminals;
  IJBToken internal _tokenV2;

  AccessJBLib internal _accessJBLib;

  //*********************************************************************//
  // --------------------------- test setup ---------------------------- //
  //*********************************************************************//

  // Deploys and initializes contracts for testing.
  function setUp() public virtual {
    // ---- Set up project ----
    _jbOperatorStore = new JBOperatorStore();
    vm.label(address(_jbOperatorStore), 'JBOperatorStore');

    _jbProjects = new JBProjects(_jbOperatorStore);
    vm.label(address(_jbProjects), 'JBProjects');

    _jbPrices = new JBPrices(_projectOwner);
    vm.label(address(_jbPrices), 'JBPrices');

    address contractAtNoncePlusOne = addressFrom(address(this), 5);

    _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(contractAtNoncePlusOne));
    vm.label(address(_jbFundingCycleStore), 'JBFundingCycleStore');

    _jbDirectory = new JBDirectory(
      _jbOperatorStore,
      _jbProjects,
      _jbFundingCycleStore,
      _projectOwner
    );
    vm.label(address(_jbDirectory), 'JBDirectory');

    _jbTokenStore = new JBTokenStore(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore
    );
    vm.label(address(_jbTokenStore), 'JBTokenStore');

    _jbSplitsStore = new JBSplitsStore(_jbOperatorStore, _jbProjects, _jbDirectory);
    vm.label(address(_jbSplitsStore), 'JBSplitsStore');

    _jbController = new JBController3_1(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore,
      _jbTokenStore,
      _jbSplitsStore
    );
    vm.label(address(_jbController), 'JBController');

    vm.prank(_projectOwner);
    _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

    _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore3_1(
      _jbDirectory,
      _jbFundingCycleStore,
      _jbPrices
    );
    vm.label(address(_jbPaymentTerminalStore), 'JBSingleTokenPaymentTerminalStore3_1');

    _accessJBLib = new AccessJBLib();

    _jbETHPaymentTerminal = new JBETHPaymentTerminal(
      _accessJBLib.ETH(),
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbSplitsStore,
      _jbPrices,
      _jbPaymentTerminalStore,
      _projectOwner
    );
    vm.label(address(_jbETHPaymentTerminal), 'JBETHPaymentTerminal');

    _terminals.push(_jbETHPaymentTerminal);

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBPayDataSourceFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({
        allowSetTerminals: false,
        allowSetController: false,
        pauseTransfers: false
      }),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 5000,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: true,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      preferClaimedTokenOverride: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForRedeem: true,
      metadata: 0x00
    });

    // ---- general setup ----
    vm.deal(_beneficiary, 100 ether);
    vm.deal(_projectOwner, 100 ether);
    vm.deal(_caller, 100 ether);

    vm.label(_projectOwner, 'projectOwner');
    vm.label(_beneficiary, 'beneficiary');
    vm.label(_caller, 'caller');
  }

  //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
  function addressFrom(address _origin, uint256 _nonce) internal pure returns (address _address) {
    bytes memory data;
    if (_nonce == 0x00) data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
    else if (_nonce <= 0x7f)
      data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
    else if (_nonce <= 0xff)
      data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
    else if (_nonce <= 0xffff)
      data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
    else if (_nonce <= 0xffffff)
      data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
    else data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
    bytes32 hash = keccak256(data);
    assembly ("memory-safe"){
      mstore(0, hash)
      _address := mload(0)
    }
  }
}
