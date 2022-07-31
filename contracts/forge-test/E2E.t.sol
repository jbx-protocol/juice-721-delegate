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
    bytes memory metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      false,
      false,
      false,
      rawMetadata
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

    if (valueSent < 110) assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
    else assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 2); // Second minted with leftover (if > lowest tier)?

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

    // 5 first tier floors
    uint256 _amountNeeded = 50 + 40 + 30 + 20 + 10;

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
    bytes memory metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      false,
      false,
      false,
      rawMetadata
    );

    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: _amountNeeded}(
      projectId,
      _amountNeeded,
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

    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

    // Check: correct tier and id?
    vm.expectEmit(true, true, true, true, NFTRewardDataSource);
    emit Mint(
      _generateTokenId(highestTier, 1),
      highestTier,
      _beneficiary,
      NFTRewardDeployerData.tierData[highestTier - 1].contributionFloor,
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
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
  }

  function testMintBeforeAndAfterTierChange(uint72 _payAmount) public {
    address _user = address(bytes20(keccak256('user')));

    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(true);
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Get the dataSource
    IJBTieredLimitedNFTRewardDataSource _delegate = IJBTieredLimitedNFTRewardDataSource(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );

    // _payAmount has to be at least the lowest tier
    vm.assume(_payAmount >= NFTRewardDeployerData.tierData[0].contributionFloor);

    // vm.expectEmit(true, true, true, true, address(_delegate));
    emit Mint(
      0,
      0,
      _beneficiary,
      _payAmount,
      0,
      address(_jbETHPaymentTerminal) // msg.sender
    );

    // Pay and mint an NFT
    vm.deal(_user, _payAmount);
    vm.prank(_user);
    _jbETHPaymentTerminal.pay{value: _payAmount}(
      projectId,
      100,
      address(0),
      _user,
      0,
      false,
      'Take my money!',
      new bytes(0)
    );

    // Get the existing tiers
    JBNFTRewardTier[] memory _originalTiers = _delegate.tiers();
    uint256[] memory _tiersToRemove = new uint256[](_originalTiers.length);
    // Append all the existing tiers
    for (uint256 _i; _i < _originalTiers.length; _i++) {
      _tiersToRemove[_i] = _originalTiers[_i].id;
    }

    // Add 1 new tier
    JBNFTRewardTierParams[] memory _tiersToAdd = new JBNFTRewardTierParams[](1);
    _tiersToAdd[0] = JBNFTRewardTierParams({
      contributionFloor: _payAmount,
      lockedUntil: uint48(0),
      remainingQuantity: uint40(100),
      initialQuantity: uint40(100),
      votingUnits: uint16(0),
      reservedRate: uint16(0),
      encodedIPFSUri: tokenUris[0]
    });

    // Remove all the existing tiers and add a new one at the previous paid price
    vm.prank(_projectOwner);
    _delegate.adjustTiers(_tiersToAdd, _tiersToRemove);

    // Mint the new NFT and make sure that it is the new tier
    // vm.expectEmit(false, true, false, false);
    emit Mint(
      0,
      _originalTiers[_originalTiers.length - 1].id + 1, // The new tier should have gotten an id 1 higher than the last
      _beneficiary,
      _payAmount,
      0,
      address(_jbETHPaymentTerminal) // msg.sender
    );

    // We now pay the exact same amount and expect to receive the new tier and not the old one
    vm.deal(_user, _payAmount);
    vm.prank(_user);
    _jbETHPaymentTerminal.pay{value: _payAmount}(
      projectId,
      100,
      address(0),
      _user,
      0,
      false,
      'Take my money!',
      new bytes(0)
    );
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
    JBNFTRewardTierParams[] memory tiers = new JBNFTRewardTierParams[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(10),
        initialQuantity: uint40(10),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        encodedIPFSUri: tokenUris[i]
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
      tiers: tiers,
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
