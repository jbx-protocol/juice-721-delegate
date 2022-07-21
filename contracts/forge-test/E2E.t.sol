pragma solidity 0.8.6;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../JBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import './utils/TestBaseWorkflow.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';

contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));

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

  JBTieredLimitedNFTRewardDataSourceProjectDeployer deployer;

  function setUp() public override {
    super.setUp();

    deployer = new JBTieredLimitedNFTRewardDataSourceProjectDeployer(
      IJBController(_jbController),
      IJBOperatorStore(_jbOperatorStore)
    );
  }

  function testDeployAndLaunchProject() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(false);
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    assertEq(projectId, 1);
  }

  function testMintOnPayIfOneTierIsPassed(uint16 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000);

    uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;

    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(false);
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    uint8[] memory rawMetadata = new uint8[](1);
    rawMetadata[0] = uint8(highestTier); // reward tier

    // Encode it to metadata
    bytes memory metadata = abi.encode(bytes32(0), rawMetadata);

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

    uint256 tokenId = _generateTokenId(highestTier, 1);

    // Check: NFT actually received?
    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), _beneficiary);
    assertEq(IJBNFTRewardDataSource(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

    // Check: firstOwnerOf and ownerOf are correct after a transfer?
    vm.prank(_beneficiary);
    IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);

    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
    assertEq(IJBNFTRewardDataSource(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

    // Check: same after a second transfer - 0xSTVG-style testing?
    vm.prank(address(696969420));
    IERC721(NFTRewardDataSource).transferFrom(address(696969420), address(123456789), tokenId);

    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(123456789));
    assertEq(IJBNFTRewardDataSource(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
  }

  function testMintOnPayIfMultipleTiersArePassed() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(false);
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    uint256 _amountNeeded = (50 * 60) / 2;

    uint8[] memory rawMetadata = new uint8[](5);

    // Mint one per tier for the first 5 tiers
    for (uint256 i = 0; i < 5; i++) {
      rawMetadata[i] = uint8(i + 1); // Not the tier 0

      // Check: correct tiers and ids?
      vm.expectEmit(true, true, true, true);
      emit Mint(
        _generateTokenId(i + 1, 1),
        i + 1,
        _beneficiary,
        _amountNeeded,
        5,
        address(_jbETHPaymentTerminal) // msg.sender
      );
    }

    // Encode it to metadata
    bytes memory metadata = abi.encode(bytes32(0), rawMetadata);

    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: _amountNeeded}(
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
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 5);

    for (uint256 i = 1; i <= 5; i++) {
      uint256 tokenId = _generateTokenId(i, 1);
      assertEq(IJBNFTRewardDataSource(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

      // Check: firstOwnerOf and ownerOf are correct after a transfer?
      vm.prank(_beneficiary);
      IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);

      assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
      assertEq(IJBNFTRewardDataSource(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
    }
  }

  function testMintOnPayUsingFallbackTiers(uint8 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000);

    uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;

    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(true);
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
      0,
      address(_jbETHPaymentTerminal) // msg.sender
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

  // Create launchProjectFor(..) payload
  function createData(bool _shouldMintByDefault)
    internal
    view
    returns (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JBNFTRewardTierData[] memory tierData = new JBNFTRewardTierData[](10);

    for (uint256 i; i < 10; i++) {
      tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(10),
        initialQuantity: uint40(10),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: _jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      contractUri: contractUri,
      baseUri: baseUri,
      owner: _projectOwner,
      tierData: tierData,
      shouldMintByDefault: _shouldMintByDefault,
      reservedTokenBeneficiary: reserveBeneficiary
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
    pure
    returns (uint256 tokenId)
  {
    // The tier ID in the first 8 bits.
    tokenId = _tierId;

    // The token number in the rest.
    tokenId |= _tokenNumber << 8;
  }
}
