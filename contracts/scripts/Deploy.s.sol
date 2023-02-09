pragma solidity ^0.8.16;

import '@jbx-protocol/juice-delegates-registry/src/interfaces/IJBDelegatesRegistry.sol';

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';

contract DeployMainnet is Script {
  IJBDirectory jbDirectory = IJBDirectory(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
  IJBSplitsStore jbSplitsStore = IJBSplitsStore(0x0D25194ABE95185Db8e4B0294F5669E21C534785);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    IJBDelegatesRegistry registry = IJBDelegatesRegistry(
      stdJson.readAddress(
        vm.readFile(
          'node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/1/run-latest.json'
        ),
        'transactions[0].contractAddress'
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

    store = new JBTiered721DelegateStore(jbSplitsStore);

    projectDeployer = new JBTiered721DelegateProjectDeployer(
      jbDirectory,
      delegateDeployer,
      jbOperatorStore
    );

    console.log('registry ', address(registry));
    console.log('project deployer', address(projectDeployer));
    console.log('store ', address(store));
  }
}

contract DeployGoerli is Script {
  IJBDirectory jbDirectory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
  IJBSplitsStore jbSplitsStore = IJBSplitsStore(0xce2Ce2F37fE5B2C2Dd047908B2F61c9c3f707272);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    IJBDelegatesRegistry registry = IJBDelegatesRegistry(
      stdJson.readAddress(
        vm.readFile(
          'node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/5/run-latest.json'
        ),
        'transactions[0].contractAddress'
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

    store = new JBTiered721DelegateStore(jbSplitsStore);

    projectDeployer = new JBTiered721DelegateProjectDeployer(
      jbDirectory,
      delegateDeployer,
      jbOperatorStore
    );

    console.log('registry ', address(registry));
    console.log('project deployer', address(projectDeployer));
    console.log('store ', address(store));
  }
}
