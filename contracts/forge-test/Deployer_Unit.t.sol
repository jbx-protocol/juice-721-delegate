pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';

import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import '../structs/JBLaunchProjectData.sol';

import 'forge-std/Test.sol';

contract TestJBTieredLimitedNFTRewardDataSourceProjectDeployer is Test {
  using stdStorage for StdStorage;

  address owner = address(42069);

  address mockJBController = address(100);
  address mockJBDirectory = address(101);
  address mockTokenUriResolver = address(102);
  address mockContributionToken = address(103);
  address mockTerminalAddress = address(104);
  address mockJBProjects = address(105);

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string tokenUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';

  string [] baseUris = [
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0', 
    'http://www.null.com/0'
    ];

  string fcMemo = 'meemoo';

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public {
    vm.label(owner, 'owner');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockContributionToken, 'mockContributionToken');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBController, 'mockJBController');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBController, new bytes(0x69));
    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockContributionToken, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(
      IJBController(mockJBController)
    );
  }

  function testLaunchProjectFor_shouldLaunchProject(uint128 previousProjectId) external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    vm.mockCall(
      mockJBController,
      abi.encodeWithSelector(IJBController.projects.selector),
      abi.encode(mockJBProjects)
    );
    vm.mockCall(
      mockJBProjects,
      abi.encodeWithSelector(IJBProjects.count.selector),
      abi.encode(previousProjectId)
    );

    vm.mockCall(
      mockJBController,
      abi.encodeWithSelector(IJBController.launchProjectFor.selector),
      abi.encode(true)
    );

    uint256 _projectId = deployer.launchProjectFor(owner, NFTRewardDeployerData, launchProjectData);

    assertEq(previousProjectId, _projectId - 1);
  }

  function testLaunchProjectFor_shouldLaunchProject_nonFuzzed() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    vm.mockCall(
      mockJBController,
      abi.encodeWithSelector(IJBController.projects.selector),
      abi.encode(mockJBProjects)
    );
    vm.mockCall(mockJBProjects, abi.encodeWithSelector(IJBProjects.count.selector), abi.encode(5));

    vm.mockCall(
      mockJBController,
      abi.encodeWithSelector(IJBController.launchProjectFor.selector),
      abi.encode(true)
    );

    uint256 _projectId = deployer.launchProjectFor(owner, NFTRewardDeployerData, launchProjectData);

    assertEq(_projectId, 6);
  }

  // -- internal helpers --

  function createData()
    internal
    view
    returns (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JBProjectMetadata memory projectMetadata;
    JBFundingCycleData memory data;
    JBFundingCycleMetadata memory metadata;
    JBGroupedSplits[] memory groupedSplits;
    JBFundAccessConstraints[] memory fundAccessConstraints;
    IJBPaymentTerminal[] memory terminals;
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        tokenUri: baseUris[i]
      });
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: IJBDirectory(mockJBDirectory),
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(mockTokenUriResolver),
      tokenUri: tokenUri,
      contractUri: contractUri,
      owner: owner,
      contributionToken: mockContributionToken,
      tiers: tiers
    });

    projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    data = JBFundingCycleData({
      duration: 14,
      weight: 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowChangeToken: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: address(0)
    });

    launchProjectData = JBLaunchProjectData({
      projectMetadata: projectMetadata,
      data: data,
      metadata: metadata,
      mustStartAtOrAfter: 0,
      groupedSplits: groupedSplits,
      fundAccessConstraints: fundAccessConstraints,
      terminals: terminals,
      memo: fcMemo
    });
  }
}
