pragma solidity 0.8.6;

import '../interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import 'forge-std/Script.sol';

// Latest NFTProjectDeployer
address constant LATEST = 0x1Db110f9FD09820c60CaFA89CB736910306bbec9;

// Change values in setUp() and createData()
contract RinkebyLaunchProjectFor is Script {
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer deployer =
    IJBTieredLimitedNFTRewardDataSourceProjectDeployer(LATEST);
  IJBController jbController;
  IJBDirectory jbDirectory;
  IJBPaymentTerminal[] _terminals;
  JBFundAccessConstraints[] _fundAccessConstraints;

  string name;
  string symbol;
  string baseUri;
  string contractUri;

  address _projectOwner;

  function setUp() public {
    _projectOwner = msg.sender; // Change me
    jbController = deployer.controller();
    jbDirectory = jbController.directory();
    name = ''; // Change me
    symbol = '';
    baseUri = '';
    contractUri = '';

  }

  function run() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    vm.startBroadcast();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    console.log(projectId);
  }

  function createData()
    internal
    returns (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    // Project configuration
    JBProjectMetadata memory _projectMetadata = JBProjectMetadata({
      content: 'QmdkypzHEZTPZUWe6FmfHLD6iSu9DebRcssFFM42cv5q8i',
      domain: 0
    });
    JBFundingCycleData memory _data = JBFundingCycleData({
      duration: 600,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    JBFundingCycleMetadata memory _metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000,
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 5000,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: true,
      allowChangeToken: true,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: true,
      useDataSourceForRedeem: true,
      dataSource: address(0) // Will get overriden during deployment
    });

    JBSplit[] memory _splits = new JBSplit[](1);
    _splits[0] = JBSplit({
      preferClaimed: false,
      preferAddToBalance: false,
      percent: 1000000000,
      projectId: 0,
      beneficiary: payable(_projectOwner),
      lockedUntil: 0,
      allocator: IJBSplitAllocator(address(0))
    });

    JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
    _groupedSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

    _terminals.push(IJBPaymentTerminal(0x765A8b9a23F58Db6c8849315C04ACf32b2D55cF8));

    _fundAccessConstraints.push(
      JBFundAccessConstraints({
        terminal: _terminals[0],
        token: address(0x000000000000000000000000000000000000EEEe), // ETH
        distributionLimit: 100 ether,
        overflowAllowance: 0,
        distributionLimitCurrency: 1, // ETH
        overflowAllowanceCurrency: 1
      })
    );

    // NFT Reward parameters
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](3);

    for (uint256 i; i < 3; i++) {
      tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 0.001 ether),
        remainingQuantity: 100,
        initialQuantity: 100,
        votingUnits: uint16(10*i),
        reservedRate: 1,
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
      });
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      contractUri: contractUri,
      baseUri: baseUri,
      owner: _projectOwner,
      tiers: tiers,
      shouldMintByDefault: true
    });

    launchProjectData = JBLaunchProjectData({
      projectMetadata: _projectMetadata,
      data: _data,
      metadata: _metadata,
      mustStartAtOrAfter: 0,
      groupedSplits: _groupedSplits,
      fundAccessConstraints: _fundAccessConstraints,
      terminals: _terminals,
      memo: ''
    });
  }
}

contract RinkebyDeployDatasource is Script {
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer deployer =
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer(LATEST);
  IJBController jbController;
  IJBDirectory jbDirectory;
  IJBPaymentTerminal[] _terminals;
  JBFundAccessConstraints[] _fundAccessConstraints;

  string name;
  string symbol;
  string contractUri;
  string baseUri;
  address _projectOwner;

  function setUp() public {
    jbController = deployer.controller();
    jbDirectory = jbController.directory();
    name = '';
    symbol = '';
    contractUri = '';
    baseUri = '';
    _projectOwner = msg.sender;
  }

  function run(uint256 projectId) external {

    // NFT Reward parameters
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](3);

    for (uint256 i; i < 3; i++) {
      tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 0.001 ether),
        remainingQuantity: 100,
        initialQuantity: 100,
        votingUnits: uint16(10*i),
        reservedRate: 1,
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
      });
    }

    JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      contractUri: contractUri,
      baseUri: baseUri,
      owner: _projectOwner,
      tiers: tiers,
      shouldMintByDefault: false
    });

    vm.broadcast();

    address NFTDatasource = deployer.deployDataSource(
      projectId,
      NFTRewardDeployerData
   );

    console.log(NFTDatasource);
    console.log(address(jbController));
    console.log(address(jbDirectory));
  }
}
