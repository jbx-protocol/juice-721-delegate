pragma solidity ^0.8.16;

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  IJBDirectory jbDirectory = IJBDirectory(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    vm.startBroadcast();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance
    );

    store = new JBTiered721DelegateStore();

    projectDeployer = new JBTiered721DelegateProjectDeployer(jbDirectory, delegateDeployer, jbOperatorStore);

    console.log(address(projectDeployer));
    console.log(address(store));
  }
}

contract DeployGoerli is Script {
  IJBDirectory jbDirectory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);

  JBTiered721DelegateDeployer delegateDeployer;
  JBTiered721DelegateProjectDeployer projectDeployer;
  JBTiered721DelegateStore store;

  function run() external {
    vm.startBroadcast();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance
    );

    store = new JBTiered721DelegateStore();

    projectDeployer = new JBTiered721DelegateProjectDeployer(jbDirectory, delegateDeployer, jbOperatorStore);

    console.log(address(projectDeployer));
    console.log(address(store));
  }
}
