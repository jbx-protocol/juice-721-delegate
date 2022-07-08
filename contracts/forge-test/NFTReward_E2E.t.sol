pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import './utils/TestBaseWorkflow.sol';

import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';

contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
  using stdStorage for StdStorage;

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

  function testMintOnPay() external {
    (JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData, JBLaunchProjectData memory launchProjectData) = createData();
    uint256 projectId = deployer.launchProjectFor(_projectOwner, NFTRewardDeployerData, launchProjectData);

    _jbETHPaymentTerminal.pay{value: 100}(
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

    assertEq(projectId, 1);
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
      expectedCaller: address(_jbETHPaymentTerminal),
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
