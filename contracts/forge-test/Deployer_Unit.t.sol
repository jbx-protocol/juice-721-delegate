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

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';

  JBNFTRewardTier[] tiers;

  string fcMemo = 'meemoo';

  JBProjectMetadata projectMetadata;
  JBFundingCycleData data;
  JBFundingCycleMetadata metadata;
  JBGroupedSplits[] groupedSplits;
  JBFundAccessConstraints[] fundAccessConstraints;
  IJBPaymentTerminal[] terminals;

  JBDeployTieredNFTRewardDataSourceData NFTRewardDeployerData;
  JBLaunchProjectData launchProjectData;

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public {
    vm.label(owner, 'owner');    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockContributionToken, 'mockContributionToken');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');

    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockContributionToken, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));

    for (uint256 i = 1; i <= 10; i++) {
      tiers.push( 
        JBNFTRewardTier({
          contributionFloor: uint128(i * 10),
          idCeiling: uint48((i * 100)),
          remainingAllowance: uint40(100),
          initialAllowance: uint40(100)
        })
      )
      ;
    }
  
  NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
    directory: IJBDirectory(mockJBDirectory),
    name: name,
    symbol: symbol,
    tokenUriResolver: IToken721UriResolver(mockTokenUriResolver),
    baseUri: baseUri,
    contractUri: contractUri,
    expectedCaller: mockTerminalAddress,
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

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(IJBController(mockJBController));
  }

  function testLaunchProjectFor_launchProject() external {
    //deployer.launchProjectFor(owner, _NFTRewardDeployerData, launchProjectData);
  }

}
