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
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    uint256 numRewards,
    address caller
  );

  event Burn(uint256 indexed tokenId, address owner, address caller);

  string name = 'NAME';
  string symbol = 'SYM';
  string tokenUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';
  string[] baseUris = [
    'http://www.null.com/0',
    'http://www.null.com/1',
    'http://www.null.com/2',
    'http://www.null.com/3',
    'http://www.null.com/4',
    'http://www.null.com/5',
    'http://www.null.com/6',
    'http://www.null.com/7',
    'http://www.null.com/8',
    'http://www.null.com/9'
  ];

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public override {
    super.setUp();

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(IJBController(_jbController));
  }

  function testDeployAndLaunchProject() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    assertEq(projectId, 1);
  }

   function testMintOnPay(uint16 valueSent) external {
     vm.assume(valueSent >= 10 && valueSent < 2000);

     uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;

     (
       JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
       JBLaunchProjectData memory launchProjectData
     ) = createData();
     uint256 projectId = deployer.launchProjectFor(
       _projectOwner,
       NFTRewardDeployerData,
       launchProjectData
     );

     // Check: correct tier and id?
     vm.expectEmit(true, true, true, true);
     emit Mint(
       _generateTokenId(highestTier, 1),
       highestTier,
       _beneficiary,
       valueSent,
       1,
       address(_jbETHPaymentTerminal) // msg.sender
     );

     uint8[] memory rawMetadata = new uint8[](1);
     rawMetadata[0] = uint8(highestTier); // reward tier

     // Encode it to metadata
     bytes memory metadata = abi.encode(bytes32(0), rawMetadata);

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
       metadata
     );

     // Check: NFT actually received?
     address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
     assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
     assertEq(IERC721(NFTRewardDataSource).ownerOf(_generateTokenId(highestTier, 1)), _beneficiary);
   }

  // ----- internal helpers ------

  // Create launchProjectFor(..) payload
  function createData()
    internal
    view
    returns (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(10),
        initialQuantity: uint40(10),
        tokenUri: baseUris[i]
      });
    }


    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: _jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      baseUri: tokenUri,
      contractUri: contractUri,
      owner: _projectOwner,
      contributionToken: _accessJBLib.ETHToken(),
      tiers: tiers,
      shouldMintByDefault: false
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

  // Generate tokenId's based on token number and tier
  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber)
    internal
    returns (uint256 tokenId)
  {
    // The tier ID in the first 8 bits.
    tokenId = _tierId;

    // The token number in the rest.
    tokenId |= _tokenNumber << 8;
  }
}
