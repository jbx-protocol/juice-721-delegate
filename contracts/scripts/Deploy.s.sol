pragma solidity ^0.8.16;

import '@jbx-protocol/juice-delegates-registry/src/interfaces/IJBDelegatesRegistry.sol';

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/Test.sol';

contract DeployMainnet is Script, Test {
  IJBController jbController = IJBController(0xFFdD70C318915879d5192e8a0dcbFcB0285b3C98);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    IJBDelegatesRegistry registry = IJBDelegatesRegistry(
      stdJson.readAddress(
        vm.readFile("node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/1/run-latest.json"),
        "transactions[0].contractAddress"
      )
    );

    // Make a static call for sanity check
    assert(registry.deployerOf(address(0)) == address(0));

    vm.startBroadcast();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance,
      registry
    );

    store = new JBTiered721DelegateStore();

    projectDeployer = new JBTiered721DelegateProjectDeployer(jbController, delegateDeployer, jbOperatorStore);

    console.log("registry ", address(registry));
    console.log("project deployer", address(projectDeployer));
    console.log("store ", address(store));
  }
}

contract DeployGoerli is Script, Test {
  IJBController jbController = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    IJBDelegatesRegistry registry = IJBDelegatesRegistry(
      stdJson.readAddress(
        vm.readFile("node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/5/run-latest.json"),
        "transactions[0].contractAddress"
      )
    );

    // Make a static call for sanity check
    assert(registry.deployerOf(address(0)) == address(0));

    vm.startBroadcast();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance,
      registry
    );

    store = new JBTiered721DelegateStore();

    projectDeployer = new JBTiered721DelegateProjectDeployer(jbController, delegateDeployer, jbOperatorStore);

    console.log("registry ", address(registry));
    console.log("project deployer", address(projectDeployer));
    console.log("store ", address(store));
  }
}
