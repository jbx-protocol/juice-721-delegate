pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';

import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import '../structs/JBLaunchProjectData.sol';

import 'forge-std/Test.sol';

contract TestJBTieredLimitedNFTRewardDataSourceProjectDeployer is Test {
  using stdStorage for StdStorage;

  address owner = address(bytes20(keccak256('owner')));
  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
  address mockJBDirectory = address(bytes20(keccak256('mockJBDirectory')));
  address mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
  address mockTerminalAddress = address(bytes20(keccak256('mockTerminalAddress')));
  address mockJBController = address(bytes20(keccak256('mockJBController')));
  address mockJBOperatorStore = address(bytes20(keccak256('mockJBOperatorStore')));
  address mockJBProjects = address(bytes20(keccak256('mockJBProjects')));

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com/';
  string contractUri = 'ipfs://null';

  //QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz
  bytes32[] tokenUris = [
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89)
  ];

  string fcMemo = 'meemoo';

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public {
    vm.label(owner, 'owner');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBController, 'mockJBController');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBController, new bytes(0x69));
    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(
      IJBController(mockJBController),
      IJBOperatorStore(mockJBOperatorStore)
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
    JBNFTRewardTierParams[] memory tiers = new JBNFTRewardTierParams[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        encodedIPFSUri: tokenUris[i]
      });
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: IJBDirectory(mockJBDirectory),
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(mockTokenUriResolver),
      contractUri: contractUri,
      baseUri: baseUri,
      owner: owner,
      tiers: tiers,
      shouldMintByDefault: false,
      reservedTokenBeneficiary: reserveBeneficiary
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
