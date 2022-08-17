pragma solidity 0.8.6;

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
    jbDelegateDeployer = new JBTiered721DelegateDeployer();
    jbTieredLimitedNFTRewardDataSource = new JBTiered721DelegateProjectDeployer(
      jbController,
      jbDelegateDeployer,
      jbOperatorStore
    );
  }
}

contract DeployRinkeby is Script {
  IJBController jbController = IJBController(0xd96ecf0E07eB197587Ad4A897933f78A00B21c9a);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0xEDB2db4b82A4D4956C3B4aA474F7ddf3Ac73c5AB);

  JBTiered721DelegateDeployer jbDelegateDeployer;
  JBTiered721DelegateProjectDeployer jbTieredLimitedNFTRewardDataSourceProjectDeployer;
  JBTiered721DelegateStore jbTieredLimitedNFTRewardDataSourceStore;

  function run() external {
    vm.startBroadcast();
    jbDelegateDeployer = new JBTiered721DelegateDeployer();

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
