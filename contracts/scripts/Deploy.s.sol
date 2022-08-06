pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSourceDeployer.sol';
import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  IJBController jbController = IJBController(0x43780E780DF2bD1e4d955d3d4b577a490841241A);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

  JBTieredLimitedNFTRewardDataSourceDeployer jbDelegateDeployer;
  JBTieredLimitedNFTRewardDataSourceProjectDeployer jbTieredLimitedNFTRewardDataSource;

  function run() external {
    vm.startBroadcast();
    jbDelegateDeployer = new JBTieredLimitedNFTRewardDataSourceDeployer();
    jbTieredLimitedNFTRewardDataSource = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(
      jbController,
      jbDelegateDeployer,
      jbOperatorStore
    );
  }
}

contract DeployRinkeby is Script {
  IJBController jbController = IJBController(0xb51e584Ee10460E9e5ea29Deab67cd347B0cA2f3);
  IJBOperatorStore jbOperatorStore = IJBOperatorStore(0xEDB2db4b82A4D4956C3B4aA474F7ddf3Ac73c5AB);

  JBTieredLimitedNFTRewardDataSourceDeployer jbDelegateDeployer;
  JBTieredLimitedNFTRewardDataSourceProjectDeployer jbTieredLimitedNFTRewardDataSource;

  function run() external {
    vm.startBroadcast();
    jbDelegateDeployer = new JBTieredLimitedNFTRewardDataSourceDeployer();
    jbTieredLimitedNFTRewardDataSource = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(
      jbController,
      jbDelegateDeployer,
      jbOperatorStore
    );
  }
}
