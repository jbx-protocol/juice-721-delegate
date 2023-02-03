pragma solidity ^0.8.16;

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  IJBController jbController = IJBController(0xFFdD70C318915879d5192e8a0dcbFcB0285b3C98);
  IJBSplitsStore jbSplitsStore = IJBSplitsStore(0x0D25194ABE95185Db8e4B0294F5669E21C534785);
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

    store = new JBTiered721DelegateStore(jbSplitsStore);

    projectDeployer = new JBTiered721DelegateProjectDeployer(
      jbController,
      delegateDeployer,
      jbOperatorStore
    );

    console.log(address(projectDeployer));
    console.log(address(store));
  }
}

contract DeployGoerli is Script {
  IJBController jbController = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
  IJBSplitsStore jbSplitsStore = IJBSplitsStore(0xce2Ce2F37fE5B2C2Dd047908B2F61c9c3f707272);
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

    store = new JBTiered721DelegateStore(jbSplitsStore);

    projectDeployer = new JBTiered721DelegateProjectDeployer(
      jbController,
      delegateDeployer,
      jbOperatorStore
    );

    console.log(address(projectDeployer));
    console.log(address(store));
  }
}
