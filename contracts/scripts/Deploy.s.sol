pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  IJBController jbController = IJBController(0x43780E780DF2bD1e4d955d3d4b577a490841241A);

  function setUp() public {}

  function run() external {
    vm.startBroadcast();
    new JBTieredLimitedNFTRewardDataSourceProjectDeployer(jbController);
  }
}

contract DeployRinkeby is Script {
  IJBController jbController = IJBController(0xb51e584Ee10460E9e5ea29Deab67cd347B0cA2f3);

  function setUp() public {}

  function run() external {
    vm.startBroadcast();
    new JBTieredLimitedNFTRewardDataSourceProjectDeployer(jbController);
  }
}
