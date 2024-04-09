pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

import { IJBDelegatesRegistry } from "@jbx-protocol/juice-delegates-registry/src/interfaces/IJBDelegatesRegistry.sol";
import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";

import { JBTiered721DelegateDeployer } from "../JBTiered721DelegateDeployer.sol";
import { JBTiered721DelegateProjectDeployer } from "../JBTiered721DelegateProjectDeployer.sol";
import { JBTiered721DelegateStore } from "../JBTiered721DelegateStore.sol";
import { JBTiered721Delegate } from "../JBTiered721Delegate.sol";
import { JBTiered721GovernanceDelegate } from "../JBTiered721GovernanceDelegate.sol";

contract DeployMainnet is Script {
    IJBDirectory jbDirectory = IJBDirectory(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
    IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

    bytes4 payMetadataDelegateId = bytes4("721P");
    bytes4 redeemMetadataDelegateId = bytes4("721R");

    JBTiered721DelegateDeployer delegateDeployer;
    JBTiered721DelegateProjectDeployer projectDeployer;
    JBTiered721DelegateStore store;

    function run() external {
        IJBDelegatesRegistry registry = IJBDelegatesRegistry(
            stdJson.readAddress(
                vm.readFile(
                    "node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/1/run-latest.json"
                ),
                ".transactions[0].contractAddress"
            )
        );

        // Make a static call for sanity check
        assert(registry.deployerOf(address(0)) == address(0));

        vm.startBroadcast();

        JBTiered721Delegate noGovernance = new JBTiered721Delegate(jbDirectory, jbOperatorStore, payMetadataDelegateId, redeemMetadataDelegateId);
        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
            jbDirectory,
            jbOperatorStore,
            payMetadataDelegateId,
            redeemMetadataDelegateId
        );

        delegateDeployer = new JBTiered721DelegateDeployer(onchainGovernance, noGovernance, registry);

        store = JBTiered721DelegateStore(0x615B5b50F1Fc591AAAb54e633417640d6F2773Fd);

        projectDeployer = new JBTiered721DelegateProjectDeployer(
            jbDirectory,
            delegateDeployer,
            jbOperatorStore
        );

        console.log("registry ", address(registry));
        console.log("project deployer", address(projectDeployer));
        console.log("store ", address(store));
    }
}

contract DeployGoerli is Script {
    IJBDirectory jbDirectory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);

    bytes4 payMetadataDelegateId = bytes4("721P");
    bytes4 redeemMetadataDelegateId = bytes4("721R");

    JBTiered721DelegateDeployer delegateDeployer;
    JBTiered721DelegateProjectDeployer projectDeployer;
    JBTiered721DelegateStore store;

    function run() external {
        IJBDelegatesRegistry registry = IJBDelegatesRegistry(
            stdJson.readAddress(
                vm.readFile(
                    "node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/5/run-latest.json"
                ),
                ".transactions[0].contractAddress"
            )
        );

        // Make a static call for sanity check
        assert(registry.deployerOf(address(0)) == address(0));

        vm.startBroadcast();

        JBTiered721Delegate noGovernance = new JBTiered721Delegate(jbDirectory, jbOperatorStore, payMetadataDelegateId, redeemMetadataDelegateId);
        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
            jbDirectory,
            jbOperatorStore,
            payMetadataDelegateId, 
            redeemMetadataDelegateId
        );

        delegateDeployer = new JBTiered721DelegateDeployer(onchainGovernance, noGovernance, registry);

        store = JBTiered721DelegateStore(0x155B49f303443a3334bB2EF42E10C628438a0656);

        projectDeployer = new JBTiered721DelegateProjectDeployer(
            jbDirectory,
            delegateDeployer,
            jbOperatorStore
        );

        console.log("registry ", address(registry));
        console.log("project deployer", address(projectDeployer));
        console.log("store ", address(store));
    }
}

contract DeploySepolia is Script {
    IJBDirectory jbDirectory = IJBDirectory(0x3B3Bd16cc76cd53218e00b600bFCa27aA5057794);
    IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x8f63C744C0280Ef4b32AF1F821c65E0fd4150ab3);

    bytes4 payMetadataDelegateId = bytes4("721P");
    bytes4 redeemMetadataDelegateId = bytes4("721R");

    JBTiered721DelegateDeployer delegateDeployer;
    JBTiered721DelegateProjectDeployer projectDeployer;
    JBTiered721DelegateStore store;

    function run() external {
        IJBDelegatesRegistry registry = IJBDelegatesRegistry(
            stdJson.readAddress(
                vm.readFile(
                    "node_modules/@jbx-protocol/juice-delegates-registry/broadcast/Deploy.s.sol/11155111/run-latest.json"
                ),
                ".transactions[0].contractAddress"
            )
        );

        // Make a static call for sanity check
        assert(registry.deployerOf(address(0)) == address(0));

        vm.startBroadcast();

        JBTiered721Delegate noGovernance = new JBTiered721Delegate(jbDirectory, jbOperatorStore, payMetadataDelegateId, redeemMetadataDelegateId);
        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
            jbDirectory,
            jbOperatorStore,
            payMetadataDelegateId, 
            redeemMetadataDelegateId
        );

        delegateDeployer = new JBTiered721DelegateDeployer(onchainGovernance, noGovernance, registry);

        store = new JBTiered721DelegateStore();

        projectDeployer = new JBTiered721DelegateProjectDeployer(
            jbDirectory,
            delegateDeployer,
            jbOperatorStore
        );

        console.log("registry ", address(registry));
        console.log("project deployer", address(projectDeployer));
        console.log("store ", address(store));
    }
}