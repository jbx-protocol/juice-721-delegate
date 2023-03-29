/**
DEPRECATED - Use jbm for now
*/


// pragma solidity ^0.8.16;

// import '../interfaces/IJBTiered721DelegateProjectDeployer.sol';
// import '../JBTiered721DelegateStore.sol';
// import 'forge-std/Script.sol';

// // Latest NFTProjectDeployer
// address constant PROJECT_DEPLOYER = 0x36F2Edc39d593dF81e7B311a9Dd74De28A6B38B1;

// // JBTiered721DelegateStore
// address constant STORE = 0x41126eC99F8A989fEB503ac7bB4c5e5D40E06FA4;

// // Change values in setUp() and createData()
// contract RinkebyLaunchProjectFor is Script {
//   IJBTiered721DelegateProjectDeployer deployer =
//     IJBTiered721DelegateProjectDeployer(PROJECT_DEPLOYER);
//   IJBController jbController;
//   IJBDirectory jbDirectory;
//   IJBFundingCycleStore jbFundingCycleStore;
//   IJBPaymentTerminal[] _terminals;
//   JBFundAccessConstraints[] _fundAccessConstraints;

//   JBTiered721DelegateStore store;

//   string name;
//   string symbol;
//   string baseUri;
//   string contractUri;

//   address _projectOwner;

//   function setUp() public {
//     _projectOwner = msg.sender; // Change me
//     jbController = deployer.controller();
//     jbDirectory = jbController.directory();
//     jbFundingCycleStore = jbController.fundingCycleStore();
//     name = ''; // Change me
//     symbol = '';
//     baseUri = '';
//     contractUri = '';
//   }

//   function run() external {
//     (
//       JBDeployTiered721DelegateData memory NFTRewardDeployerData,
//       JBLaunchProjectData memory launchProjectData
//     ) = createData();

//     vm.startBroadcast();

//     uint256 projectId = deployer.launchProjectFor(
//       _projectOwner,
//       NFTRewardDeployerData,
//       launchProjectData
//     );

//     console.log(projectId);
//   }

//   function createData()
//     internal
//     returns (
//       JBDeployTiered721DelegateData memory NFTRewardDeployerData,
//       JBLaunchProjectData memory launchProjectData
//     )
//   {
//     // Project configuration
//     JBProjectMetadata memory _projectMetadata = JBProjectMetadata({
//       content: 'QmdkypzHEZTPZUWe6FmfHLD6iSu9DebRcssFFM42cv5q8i',
//       domain: 0
//     });

//     JBFundingCycleData memory _data = JBFundingCycleData({
//       duration: 600,
//       weight: 1000 * 10**18,
//       discountRate: 450000000,
//       ballot: IJBFundingCycleBallot(address(0))
//     });

//     JBPayDataSourceFundingCycleMetadata memory _metadata = JBPayDataSourceFundingCycleMetadata({
//       global: JBGlobalFundingCycleMetadata({
//         allowSetTerminals: false,
//         allowSetController: false,
//         pauseTransfers: false
//       }),
//       reservedRate: 5000,
//       redemptionRate: 5000, //50%
//       ballotRedemptionRate: 5000,
//       pausePay: false,
//       pauseDistributions: false,
//       pauseRedeem: false,
//       pauseBurn: false,
//       allowMinting: true,
//       allowTerminalMigration: false,
//       allowControllerMigration: false,
//       holdFees: false,
//       preferClaimedTokenOverride: false,
//       useTotalOverflowForRedemptions: false,
//       useDataSourceForRedeem: true,
//       metadata: 0
//     });

//     JBSplit[] memory _splits = new JBSplit[](1);
//     _splits[0] = JBSplit({
//       preferClaimed: false,
//       preferAddToBalance: false,
//       percent: 1000000000,
//       projectId: 0,
//       beneficiary: payable(_projectOwner),
//       allocator: IJBSplitAllocator(address(0))
//     });

//     JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
//     _groupedSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

//     _terminals.push(IJBPaymentTerminal(0x765A8b9a23F58Db6c8849315C04ACf32b2D55cF8));

//     _fundAccessConstraints.push(
//       JBFundAccessConstraints({
//         terminal: _terminals[0],
//         token: address(0x000000000000000000000000000000000000EEEe), // ETH
//         distributionLimit: 100 ether,
//         overflowAllowance: 0,
//         distributionLimitCurrency: 1, // ETH
//         overflowAllowanceCurrency: 1
//       })
//     );

//     // NFT Reward parameters
//     JB721TierParams[] memory tiers = new JB721TierParams[](3);

//     for (uint256 i; i < 3; i++) {
//       tiers[i] = JB721TierParams({
//         price: uint80(i * 0.001 ether),
//         initialQuantity: 100,
//         votingUnits: uint16(10 * i),
//         reservedRate: 1,
//         reservedTokenBeneficiary: address(0),
//         royaltyRate: uint8(0),
//         royaltyBeneficiary: address(0),
//         encodedIPFSUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89,
//         category: 100,
//         allowManualMint: false,
//         shouldUseReservedTokenBeneficiaryAsDefault: true,
//         shouldUseRoyaltyBeneficiaryAsDefault: true,
//         transfersPausable: false
//       });
//     }

//     NFTRewardDeployerData = JBDeployTiered721DelegateData({
//       directory: jbDirectory,
//       name: name,
//       symbol: symbol,
//       fundingCycleStore: jbFundingCycleStore,
//       baseUri: baseUri,
//       tokenUriResolver: IJBTokenUriResolver(address(0)),
//       contractUri: contractUri,
//       owner: _projectOwner,
//       pricing: JB721PricingParams({
//         tiers: tiers,
//         currency: 1,
//         decimals: 18,
//         prices: IJBPrices(address(0))
//       }),
//       reservedTokenBeneficiary: msg.sender,
//       store: IJBTiered721DelegateStore(STORE),
//       flags: JBTiered721Flags({
// preventOverspending: false,
//         lockReservedTokenChanges: true,
//         lockVotingUnitChanges: true,
//         lockManualMintingChanges: true
//       }),
//       governanceType: JB721GovernanceType.NONE
//     });

//     launchProjectData = JBLaunchProjectData({
//       projectMetadata: _projectMetadata,
//       data: _data,
//       metadata: _metadata,
//       mustStartAtOrAfter: 0,
//       groupedSplits: _groupedSplits,
//       fundAccessConstraints: _fundAccessConstraints,
//       terminals: _terminals,
//       memo: ''
//     });
//   }
// }
