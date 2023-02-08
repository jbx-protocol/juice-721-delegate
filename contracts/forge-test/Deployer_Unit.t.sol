pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol';

import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateStore.sol';
import '../enums/JB721GovernanceType.sol';
import '../interfaces/IJBTiered721DelegateProjectDeployer.sol';
import '../structs/JBLaunchProjectData.sol';

import 'forge-std/Test.sol';

contract TestJBTiered721DelegateProjectDeployer is Test {
  using stdStorage for StdStorage;
  address owner = address(bytes20(keccak256('owner')));
  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
  address mockJBDirectory = address(bytes20(keccak256('mockJBDirectory')));
  address mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
  address mockTerminalAddress = address(bytes20(keccak256('mockTerminalAddress')));
  address mockJBController = address(bytes20(keccak256('mockJBController')));
  address mockJBFundingCycleStore = address(bytes20(keccak256('mockJBFundingCycleStore')));
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
  IJBTiered721DelegateStore store;
  IJBTiered721DelegateProjectDeployer deployer;
  IJBTiered721DelegateDeployer delegateDeployer;
  JBDelegatesRegistry delegatesRegistry;

  function setUp() public {
    vm.label(owner, 'owner');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBController, 'mockJBController');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockJBFundingCycleStore, 'mockJBFundingCycleStore');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBController, new bytes(0x69));
    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockJBFundingCycleStore, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));
    store = new JBTiered721DelegateStore();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();
    delegatesRegistry = new JBDelegatesRegistry();

    delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance,
      delegatesRegistry
    );

    deployer = new JBTiered721DelegateProjectDeployer(
      IJBDirectory(mockJBDirectory),
      delegateDeployer,
      IJBOperatorStore(mockJBOperatorStore)
    );
  }

  function testLaunchProjectFor_shouldLaunchProject(uint128 previousProjectId) external {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();
    vm.mockCall(
      mockJBDirectory,
      abi.encodeWithSelector(IJBDirectory.projects.selector),
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
    uint256 _projectId = deployer.launchProjectFor(owner, NFTRewardDeployerData, launchProjectData, IJBController3_1(mockJBController));
    assertEq(previousProjectId, _projectId - 1);
  }

  function testLaunchProjectFor_shouldLaunchProject_nonFuzzed() external {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();
    vm.mockCall(
      mockJBDirectory,
      abi.encodeWithSelector(IJBDirectory.projects.selector),
      abi.encode(mockJBProjects)
    );
    vm.mockCall(mockJBProjects, abi.encodeWithSelector(IJBProjects.count.selector), abi.encode(5));
    vm.mockCall(
      mockJBController,
      abi.encodeWithSelector(IJBController.launchProjectFor.selector),
      abi.encode(true)
    );
    uint256 _projectId = deployer.launchProjectFor(owner, NFTRewardDeployerData, launchProjectData, IJBController3_1(mockJBController));
    assertEq(_projectId, 6);
  }

  // -- internal helpers --
  function createData()
    internal
    view
    returns (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JBProjectMetadata memory projectMetadata;
    JBFundingCycleData memory data;
    JBPayDataSourceFundingCycleMetadata memory metadata;
    JBGroupedSplits[] memory groupedSplits;
    JBFundAccessConstraints[] memory fundAccessConstraints;
    IJBPaymentTerminal[] memory terminals;
    JB721TierParams[] memory tierParams = new JB721TierParams[](10);

    for (uint256 i; i < 10; i++) {
      tierParams[i] = JB721TierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        reservedTokenBeneficiary: reserveBeneficiary,
        royaltyRate: uint8(1),
        royaltyBeneficiary: reserveBeneficiary,
        encodedIPFSUri: tokenUris[i],
        category: uint8(100),
        allowManualMint: false,
        shouldUseRoyaltyBeneficiaryAsDefault: true,
        shouldUseReservedTokenBeneficiaryAsDefault: false,
        transfersPausable: false
      });
    }

    NFTRewardDeployerData = JBDeployTiered721DelegateData({
      name: name,
      symbol: symbol,
      fundingCycleStore: IJBFundingCycleStore(mockJBFundingCycleStore),
      baseUri: baseUri,
      tokenUriResolver: IJBTokenUriResolver(mockTokenUriResolver),
      contractUri: contractUri,
      owner: owner,
      pricing: JB721PricingParams({
        tiers: tierParams,
        currency: 1,
        decimals: 18,
        prices: IJBPrices(address(0))
      }),
      reservedTokenBeneficiary: reserveBeneficiary,
      store: store,
      flags: JBTiered721Flags({
        preventOverspending: false,
        lockReservedTokenChanges: true,
        lockVotingUnitChanges: true,
        lockManualMintingChanges: true
      }),
      governanceType: JB721GovernanceType.NONE
    });

    projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    data = JBFundingCycleData({
      duration: 14,
      weight: 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    metadata = JBPayDataSourceFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({
        allowSetTerminals: false,
        allowSetController: false,
        pauseTransfers: false
      }),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      preferClaimedTokenOverride: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForRedeem: false,
      metadata: 0x00
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
