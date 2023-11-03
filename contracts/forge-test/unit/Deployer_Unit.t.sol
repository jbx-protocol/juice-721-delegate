pragma solidity ^0.8.16;

import "@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController3_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPrices.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../JBTiered721DelegateProjectDeployer.sol";
import "../../JBTiered721DelegateStore.sol";
import "../../enums/JB721GovernanceType.sol";
import "../../interfaces/IJBTiered721DelegateProjectDeployer.sol";
import "../../structs/JBLaunchProjectData.sol";
import "../../structs/JB721PricingParams.sol";

import "../utils/UnitTestSetup.sol";

contract TestJBTiered721DelegateProjectDeployer_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    // bytes4 PAY_DELEGATE_ID = bytes4(hex"70");
    // bytes4 REDEEM_DELEGATE_ID = bytes4(hex"71");

    IJBTiered721DelegateProjectDeployer deployer;

    function setUp() public override {
        super.setUp();

        JBTiered721Delegate noGovernance = new JBTiered721Delegate(
            IJBDirectory(mockJBDirectory), 
            IJBOperatorStore(mockJBOperatorStore), 
            PAY_DELEGATE_ID, 
            REDEEM_DELEGATE_ID
        );

        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
            IJBDirectory(mockJBDirectory),
            IJBOperatorStore(mockJBOperatorStore),
            PAY_DELEGATE_ID,
            REDEEM_DELEGATE_ID
        );

        deployer = new JBTiered721DelegateProjectDeployer(
            IJBDirectory(mockJBDirectory),
            jbDelegateDeployer,
            IJBOperatorStore(mockJBOperatorStore)
        );
    }

    function testLaunchProjectFor_shouldLaunchProject(uint256 previousProjectId) external {
        // Include launching the protocol project (1)
        previousProjectId = bound(previousProjectId, 0, type(uint88).max - 1);

        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();

        // Mock and check
        mockAndExpect(mockJBDirectory, abi.encodeWithSelector(IJBDirectory.projects.selector), abi.encode(mockJBProjects));
        mockAndExpect(mockJBProjects, abi.encodeWithSelector(IERC721.ownerOf.selector), abi.encode(owner));
        mockAndExpect(mockJBProjects, abi.encodeWithSelector(IJBProjects.count.selector), abi.encode(previousProjectId));
        mockAndExpect(mockJBController, abi.encodeWithSelector(IJBController3_1.launchProjectFor.selector), abi.encode(true));

        // Test: launch project
        uint256 _projectId = deployer.launchProjectFor(
            owner, tiered721DeployerData, launchProjectData, IJBController3_1(mockJBController)
        );

        // Check: correct project id?
        assertEq(previousProjectId, _projectId - 1);
    }
}
