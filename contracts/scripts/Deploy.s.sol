pragma solidity ^0.8.16;

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  IJBController jbController = IJBController(0x43780E780DF2bD1e4d955d3d4b577a490841241A);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

  JBTiered721DelegateDeployer jbDelegateDeployer;
  JBTiered721DelegateProjectDeployer jbTieredLimitedNFTRewardDataSource;

  function run() external {
    vm.startBroadcast();
    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    jbDelegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance
    );
    jbTieredLimitedNFTRewardDataSource = new JBTiered721DelegateProjectDeployer(
      jbController,
      jbDelegateDeployer,
      jbOperatorStore
    );
  }
}

contract DeployGoerli is Script {
  IJBController jbController = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);

  JB721GlobalGovernance globalGovernance;
  JB721TieredGovernance tieredGovernance;
  JBTiered721Delegate noGovernance;

  JBTiered721DelegateDeployer jbDelegateDeployer;
  JBTiered721DelegateProjectDeployer jbTieredLimitedNFTRewardDataSourceProjectDeployer;
  JBTiered721DelegateStore jbTieredLimitedNFTRewardDataSourceStore;

  function run() external {
    vm.startBroadcast();

    noGovernance = new JBTiered721Delegate();
    globalGovernance = new JB721GlobalGovernance();
    tieredGovernance = new JB721TieredGovernance();

    jbDelegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance
    );

    jbTieredLimitedNFTRewardDataSourceProjectDeployer = new JBTiered721DelegateProjectDeployer(
      jbController,
      jbDelegateDeployer,
      jbOperatorStore
    );

    jbTieredLimitedNFTRewardDataSourceStore = new JBTiered721DelegateStore();

    console.log(address(jbTieredLimitedNFTRewardDataSourceProjectDeployer));
    console.log(address(jbTieredLimitedNFTRewardDataSourceStore));
  }
}
