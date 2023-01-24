pragma solidity ^0.8.16;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '../JBTiered721Delegate.sol';
import '../JBTiered721DelegateProjectDeployer.sol';
import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721DelegateStore.sol';

import './utils/TestBaseWorkflow.sol';
import '../interfaces/IJBTiered721Delegate.sol';

contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));

  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
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
  JBTiered721DelegateProjectDeployer deployer;

  function setUp() public override {
    super.setUp();

    JBTiered721Delegate noGovernance = new JBTiered721Delegate();
    JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
    JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();

    JBTiered721DelegateDeployer delegateDeployer = new JBTiered721DelegateDeployer(
      globalGovernance,
      tieredGovernance,
      noGovernance
    );

    deployer = new JBTiered721DelegateProjectDeployer(
      IJBController(_jbController),
      delegateDeployer,
      IJBOperatorStore(_jbOperatorStore)
    );
  }

  function testDeployAndLaunchProject() external {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Check: first project has the id 1?
    assertEq(projectId, 1);
  }

  function testMintOnPayIfOneTierIsPassed(uint16 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000);

    // Highest possible tier is 10
    uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Craft the metadata: claim from the highest tier
    uint16[] memory rawMetadata = new uint16[](1);
    rawMetadata[0] = uint16(highestTier);
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      true,
      rawMetadata
    );

    // Check: correct tier and id?
    vm.expectEmit(true, true, true, true);
    emit Mint(
      _generateTokenId(highestTier, 1),
      highestTier,
      _beneficiary,
      valueSent,
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
    if (valueSent < 10) {
      assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
    } else {
      assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
    }

    // Second minted with leftover (if > lowest tier)?
    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), _beneficiary);
    assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

    // Check: firstOwnerOf and ownerOf are correct after a transfer?
    vm.prank(_beneficiary);
    IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);
    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
    assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

    // Check: same after a second transfer - 0xSTVG-style testing?
    vm.prank(address(696969420));
    IERC721(NFTRewardDataSource).transferFrom(address(696969420), address(123456789), tokenId);
    assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(123456789));
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().firstOwnerOf(NFTRewardDataSource, tokenId),
      _beneficiary
    );
  }

  function testMintOnPayIfMultipleTiersArePassed() external {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // 5 first tier floors
    uint256 _amountNeeded = 50 + 40 + 30 + 20 + 10;
    uint16[] memory rawMetadata = new uint16[](5);

    // Mint one per tier for the first 5 tiers
    for (uint256 i = 0; i < 5; i++) {
      rawMetadata[i] = uint16(i + 1); // Not the tier 0
      // Check: correct tiers and ids?
      vm.expectEmit(true, true, true, true);
      emit Mint(
        _generateTokenId(i + 1, 1),
        i + 1,
        _beneficiary,
        _amountNeeded,
        address(_jbETHPaymentTerminal) // msg.sender
      );
    }

    // Encode it to metadata
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      true,
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
      assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);

      // Check: firstOwnerOf and ownerOf are correct after a transfer?
      vm.prank(_beneficiary);
      IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);
      assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
      assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
    }
  }

  function testNoMintOnPayWhenNotIncludingTierIds(uint16 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000);
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

    bool _allowOverspending = true;
    uint16[] memory rawMetadata = new uint16[](0);
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      _allowOverspending,
      rawMetadata
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

    // Check: No NFT was minted
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
    // Check: User Received the credits
    assertEq(IJBTiered721Delegate(NFTRewardDataSource).creditsOf(_beneficiary), valueSent);
  }

  // TODO This needs care (fuzz fails with insuf reserve for val=10)
  function testMintReservedToken() external {
    uint16 valueSent = 1500;
    vm.assume(valueSent >= 10 && valueSent < 2000);
    uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

    // Check: 0 reserved token before any mint from a contribution?
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
        NFTRewardDataSource,
        highestTier
      ),
      0
    );

    // Check: cannot mint 0 reserved token?
    vm.expectRevert(
      abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector)
    );

    vm.prank(_projectOwner);
    IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);

    uint16[] memory rawMetadata = new uint16[](1);
    rawMetadata[0] = uint16(highestTier); // reward tier
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      true,
      rawMetadata
    );

    // Check: correct tier and id?
    vm.expectEmit(true, true, true, true);
    emit Mint(
      _generateTokenId(highestTier, 1), // First one
      highestTier,
      _beneficiary,
      valueSent,
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

    // Check: new reserved one (1 minted == 1 reserved, due to rounding up)
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
        NFTRewardDataSource,
        highestTier
      ),
      1
    );

    // Mint the reserved token
    vm.prank(_projectOwner);
    IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);

    // Check: NFT received?
    assertEq(IERC721(NFTRewardDataSource).balanceOf(reserveBeneficiary), 1);

    // Check: no more reserved token to mint?
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
        NFTRewardDataSource,
        highestTier
      ),
      0
    );

    // Check: cannot mint more reserved token?
    vm.expectRevert(
      abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector)
    );

    vm.prank(_projectOwner);
    IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);
  }

  // Will:
  // - Mint token
  // - check the remaining reserved supply within the corresponding tier
  // - burn from that tier
  // - recheck the remaining reserved supply (which should be back to the initial one)
  function testRedeemToken(uint16 valueSent) external {
    vm.assume(valueSent >= 10 && valueSent < 2000);

    // Highest possible tier is 10
    uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;

    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Craft the metadata: claim from the highest tier
    bytes memory metadata;
    {
      uint16[] memory rawMetadata = new uint16[](1);
      rawMetadata[0] = uint16(highestTier);
      metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        true,
        rawMetadata
      );
    }

    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: valueSent}(
      projectId,
      100, // _amount
      address(0), // _token
      _beneficiary,
      0, // _minReturnedTokens
      false, //_preferClaimedTokens
      'Take my money!', // _memo
      metadata //_delegateMetadata
    );

    uint256 tokenId = _generateTokenId(highestTier, 1);
    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

    // New token balance
    uint256 tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);

    // Craft the metadata: redeem the tokenId
    uint256[] memory redemptionId = new uint256[](1);
    redemptionId[0] = tokenId;
    bytes memory redemptionMetadata = abi.encode(
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      redemptionId
    );

    vm.prank(_beneficiary);
    _jbETHPaymentTerminal.redeemTokensOf({
      _holder: _beneficiary,
      _projectId: projectId,
      _tokenCount: 0,
      _token: address(0),
      _minReturnedTokens: 0,
      _beneficiary: payable(_beneficiary),
      _memo: 'imma out of here',
      _metadata: redemptionMetadata
    });

    // Check: NFT actually redeemed?
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), tokenBalance - 1);

    // Check: Burn accounted?
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfBurnedFor(
        NFTRewardDataSource,
        highestTier
      ),
      1
    );

    // Calculate if we are rounding up or not. Used to verify 'numberOfReservedTokensOutstandingFor'
    uint256 _rounding;
    {
      JB721Tier memory _tier = IJBTiered721Delegate(NFTRewardDataSource).store().tier(
        NFTRewardDataSource,
        highestTier
      );
      // '_reserveTokensMinted' is always 0 here
      uint256 _numberOfNonReservesMinted = _tier.initialQuantity - _tier.remainingQuantity;
      _rounding = _numberOfNonReservesMinted % _tier.reservedRate > 0 ? 1 : 0;
    }

    // Check: Reserved left to mint is ?
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
        NFTRewardDataSource,
        highestTier
      ),
      (tokenBalance / NFTRewardDeployerData.pricing.tiers[highestTier - 1].reservedRate + _rounding)
    );
  }

  // Will:
  // - Mint token
  // - check the remaining supply within the corresponding tier (highest tier == 10, reserved rate is maximum -> 5)
  // - burn all the corresponding token from that tier

  function testRedeemAll() external {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    uint256 tier = 10;
    uint256 floor = NFTRewardDeployerData.pricing.tiers[tier - 1].contributionFloor;

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Craft the metadata: claim 5 from the tier
    uint16[] memory rawMetadata = new uint16[](5);
    for (uint256 i; i < rawMetadata.length; i++) rawMetadata[i] = uint16(tier);

    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      true,
      rawMetadata
    );

    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: floor * rawMetadata.length}(
      projectId,
      100, // _amount
      address(0), // _token
      _beneficiary,
      0, // _minReturnedTokens
      false, //_preferClaimedTokens
      'Take my money!', // _memo
      metadata //_delegateMetadata
    );

    address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

    // New token balance
    uint256 tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);

    // Reserved token available to mint
    uint256 reservedOutstanding = IJBTiered721Delegate(NFTRewardDataSource)
      .store()
      .numberOfReservedTokensOutstandingFor(NFTRewardDataSource, tier);

    // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null values)
    assertEq(rawMetadata.length, tokenBalance);
    assertEq(
      reservedOutstanding,
      (tokenBalance / NFTRewardDeployerData.pricing.tiers[tier - 1].reservedRate) + 1
    );

    // Craft the metadata to redeem the tokenId's
    uint256[] memory redemptionId = new uint256[](5);
    for (uint256 i; i < rawMetadata.length; i++) {
      uint256 tokenId = _generateTokenId(tier, i + 1);
      redemptionId[i] = tokenId;
    }

    bytes memory redemptionMetadata = abi.encode(
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      redemptionId
    );

    vm.prank(_beneficiary);
    _jbETHPaymentTerminal.redeemTokensOf({
      _holder: _beneficiary,
      _projectId: projectId,
      _tokenCount: 0,
      _token: address(0),
      _minReturnedTokens: 0,
      _beneficiary: payable(_beneficiary),
      _memo: 'imma out of here',
      _metadata: redemptionMetadata
    });

    // Check: NFT actually redeemed?
    assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);

    // Check: Burn accounted?
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfBurnedFor(
        NFTRewardDataSource,
        tier
      ),
      5
    );

    // Check: Reserved left to mint is back to 0
    assertEq(
      IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
        NFTRewardDataSource,
        tier
      ),
      0
    );

    // Check: Can mint again the token previously burned
    vm.prank(_caller);
    _jbETHPaymentTerminal.pay{value: floor * rawMetadata.length}(
      projectId,
      100, // _amount
      address(0), // _token
      _beneficiary,
      0, // _minReturnedTokens
      false, //_preferClaimedTokens
      'Take my money!', // _memo
      metadata //_delegateMetadata
    );

    // New token balance
    tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);

    // Reserved token available to mint is back at prev value too
    reservedOutstanding = IJBTiered721Delegate(NFTRewardDataSource)
      .store()
      .numberOfReservedTokensOutstandingFor(NFTRewardDataSource, tier);

    // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null values)
    assertEq(rawMetadata.length, tokenBalance);
    assertEq(
      reservedOutstanding,
      (tokenBalance / NFTRewardDeployerData.pricing.tiers[tier - 1].reservedRate) + 1
    );
  }

  // ----- internal helpers ------
  // Create launchProjectFor(..) payload
  function createData()
    internal
    returns (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JB721TierParams[] memory tierParams = new JB721TierParams[](10);

    for (uint256 i; i < 10; i++) {
      tierParams[i] = JB721TierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        initialQuantity: uint40(10),
        votingUnits: uint16((i + 1) * 10),
        reservedRate: 10,
        reservedTokenBeneficiary: reserveBeneficiary,
        encodedIPFSUri: tokenUris[i],
        category: uint8(100),
        allowManualMint: false,
        shouldUseBeneficiaryAsDefault: false,
        transfersPausable: false
      });
    }

    NFTRewardDeployerData = JBDeployTiered721DelegateData({
      directory: _jbDirectory,
      name: name,
      symbol: symbol,
      fundingCycleStore: _jbFundingCycleStore,
      baseUri: baseUri,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      contractUri: contractUri,
      owner: _projectOwner,
      pricing: JB721PricingParams({
        tiers: tierParams,
        currency: 1,
        decimals: 18,
        prices: IJBPrices(address(0))
      }),
      reservedTokenBeneficiary: reserveBeneficiary,
      store: new JBTiered721DelegateStore(),
      flags: JBTiered721Flags({
        preventOverspending: false,
        lockReservedTokenChanges: false,
        lockVotingUnitChanges: false,
        lockManualMintingChanges: true
      }),
      governanceType: JB721GovernanceType.NONE
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
  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
    return (_tierId * 1_000_000_000) + _tokenNumber;
  }
}
