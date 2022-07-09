pragma solidity 0.8.6;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import './utils/TestBaseWorkflow.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';

contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tier,
    address indexed beneficiary,
    uint256 value,
    address caller
  );

  event Burn(uint256 indexed tokenId, address owner, address caller);

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public override {
    super.setUp();

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(IJBController(_jbController));
  }

  function testDeployAndLaunchProject() external {
    (JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData, JBLaunchProjectData memory launchProjectData) = createData();
    uint256 projectId = deployer.launchProjectFor(_projectOwner, NFTRewardDeployerData, launchProjectData);

    assertEq(projectId, 1);
  }

  function testMintOnPay(uint256 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000 );

    uint256 theoreticalTokenId = valueSent <= 100
      ? ((((uint256(valueSent) / 10) - 1) * 10) + 1)
      : 91;

    uint256 theoreticalTiers = valueSent <= 100 ? (valueSent / 10) : 10;

    (JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData, JBLaunchProjectData memory launchProjectData) = createData();
    uint256 projectId = deployer.launchProjectFor(_projectOwner, NFTRewardDeployerData, launchProjectData);

    // Check: correct tier and id?
    vm.expectEmit(true, true, true, true);
    emit Mint(
      theoreticalTokenId,
      theoreticalTiers,
      _beneficiary,
      valueSent,
      address(_jbPaymentTerminalStore) // msg.sender
    );

    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: valueSent}(
      projectId,
      100,
      address(0),
      _beneficiary,
      /* _minReturnedTokens */
      0,
      /* _preferClaimedTokens */
      false,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    // Check: NFT actually received?
    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
  }

  // ----- internal helpers ------

  function createData() internal view returns(JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData, JBLaunchProjectData memory launchProjectData) {
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] =
        JBNFTRewardTier({
          contributionFloor: uint128( (i+1) * 10),
          idCeiling: uint48((i+1) * 10),
          remainingAllowance: uint40(10),
          initialAllowance: uint40(10)
        })
      ;
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: _jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IToken721UriResolver(address(0)),
      baseUri: baseUri,
      contractUri: contractUri,
      expectedCaller: address(_jbPaymentTerminalStore),
      owner: _projectOwner,
      contributionToken: _accessJBLib.ETHToken(),
      tiers: tiers
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
