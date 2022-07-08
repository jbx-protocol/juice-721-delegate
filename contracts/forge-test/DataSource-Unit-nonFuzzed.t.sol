// This is only for Forge coverage purpose (skipping the fuzzed tests) and should reflect Datasour-Unit.t.sol

pragma solidity 0.8.6;
import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;

  address beneficiary = address(69420);
  address owner = address(42069);
  address mockJBDirectory = address(100);
  address mockTokenUriResolver = address(2);
  address mockContributionToken = address(3);
  address mockTerminalAddress = address(4);

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';

  JBNFTRewardTier[] tiers;

  JBTieredLimitedNFTRewardDataSource delegate;

  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tier,
    address indexed beneficiary,
    uint256 value,
    address caller
  );

  event Burn(uint256 indexed tokenId, address owner, address caller);

  function setUp() public {
    vm.label(beneficiary, 'beneficiary');
    vm.label(owner, 'owner');
    vm.label(mockJBDirectory, 'mockJBDirectory');
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
      );
    }

    delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      tiers
    );
  }

  function testJBTieredNFTRewardDelegate_constructor_deployIfTiersSorted() public {
    uint256 nbTiers = 10;
    vm.assume(nbTiers < 20);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48(i * 100),
        remainingAllowance: uint40(100),
        initialAllowance: uint40(100)
      });
    }

    JBTieredLimitedNFTRewardDataSource _delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      _tiers
    );

    assertEq(_delegate.projectId(), projectId);
    assertEq(address(_delegate.directory()), mockJBDirectory);
    assertEq(_delegate.name(), name);
    assertEq(_delegate.symbol(), symbol);
    assertEq(address(_delegate.tokenUriResolver()), mockTokenUriResolver);
    assertEq(_delegate.baseUri(), baseUri);
    assertEq(_delegate.contractUri(), contractUri);
    assertEq(_delegate.owner(), owner);
    assertEq(_delegate.contributionToken(), mockContributionToken);
    assertEq(_delegate.tiers(), _tiers);
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfPriceTiersNonSorted()
    public
  {
    uint256 nbTiers = 15;
    uint256 errorIndex = 6;
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
    vm.assume(errorIndex + 1 < nbTiers); // We'll create an error between i and i+1

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48(i * 100),
        remainingAllowance: uint40(100),
        initialAllowance: uint40(100)
      });
    }

    (_tiers[errorIndex].contributionFloor, _tiers[errorIndex + 1].contributionFloor) = (
      _tiers[errorIndex + 1].contributionFloor,
      _tiers[errorIndex].contributionFloor
    );

    for (uint256 i; i < nbTiers; i++) emit log_uint(_tiers[i].contributionFloor);

    vm.expectRevert(abi.encodeWithSignature('INVALID_PRICE_SORT_ORDER(uint256)', errorIndex + 1));

    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      _tiers
    );
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfIdCeilingsNonSorted()
    public
  {
    uint256 nbTiers = 15;
    uint256 errorIndex = 6;
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
    vm.assume(errorIndex + 1 < nbTiers); // We'll create an error between i and i+1

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48(i * 100),
        remainingAllowance: uint40(100),
        initialAllowance: uint40(100)
      });
    }

    _tiers[errorIndex].idCeiling++;

    for (uint256 i; i < nbTiers; i++) emit log_uint(_tiers[i].contributionFloor);

    vm.expectRevert(abi.encodeWithSignature('INVALID_ID_SORT_ORDER(uint256)', errorIndex));

    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      _tiers
    );
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsCorrectTotalSupply() external {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        baseUri,
        contractUri,
        mockTerminalAddress,
        owner,
        mockContributionToken,
        tiers
      );

    uint256 supply;

    // Different remaining allowance to simulate different tiers minted in the same time
    for (uint256 i = 1; i < tiers.length; i++) {
      _delegate.setTier(
        i,
        JBNFTRewardTier({
          contributionFloor: uint128(i * 10),
          idCeiling: uint48((i + 1) * 100),
          remainingAllowance: uint40(i * 10),
          initialAllowance: uint40(100)
        })
      );

      supply += 100 - (i * 10);
    }

    assertEq(_delegate.totalSupply(), supply);
  }

  function testJBTieredNFTRewardDelegate_tierNumberOfToken_returnsCorrectTierNumber() external {
    uint256 tokenId = 56;
    // Tiers are from 1 to 10, with 100 token per tier

    // If in an existing tier, should return it
    if (tokenId <= 10 * 100)
      assertEq(delegate.tierNumberOfToken(tokenId), (tokenId / 100) + 1);
      // If outside of existing tiers, should return 0&@@
    else assertEq(delegate.tierNumberOfToken(tokenId), 0);
  }

  function testJBTieredNFTRewardDelegate_mint_mintIfCallerIsOwner() external {
    uint256 valueSent = 500;
    // First tier floor is 10 and last tier is 1000
    vm.assume(valueSent >= 10 && valueSent <= 2000);

    uint256 theoreticalTokenId = valueSent <= 100
      ? ((((uint256(valueSent) / 10) - 1) * 100) + 1)
      : 901;

    uint256 theoreticalTiers = valueSent <= 100 ? (valueSent / 10) : 10;

    // Check: correct event
    vm.expectEmit(true, true, true, true, address(delegate));
    emit Mint(theoreticalTokenId, theoreticalTiers, beneficiary, valueSent, owner);

    // Actual call
    vm.prank(owner);
    uint256 tokenId = delegate.mint(beneficiary, valueSent);

    // Check: allowance left - tiers are 1-indexed
    assertEq(
      delegate.tiers()[theoreticalTiers - 1].remainingAllowance,
      tiers[theoreticalTiers - 1].remainingAllowance - 1
    );

    // Check: tokenId?
    assertEq(tokenId, theoreticalTokenId);

    // Check: beneficiary balance
    assertEq(delegate.totalOwnerBalance(beneficiary), 1);
  }

  function testJBTieredNFTRewardDelegate_mint_revertIfNoAllowanceLeft() external {
    uint256 valueSent = 500;
    vm.assume(valueSent >= 10);
    uint256 theoreticalTiers = valueSent <= 100 ? (valueSent / 10) : 10;

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        baseUri,
        contractUri,
        mockTerminalAddress,
        owner,
        mockContributionToken,
        tiers
      );

    _delegate.setTier(
      theoreticalTiers - 1,
      JBNFTRewardTier({
        contributionFloor: uint128(theoreticalTiers * 10),
        idCeiling: uint48(theoreticalTiers * 100),
        remainingAllowance: 0,
        initialAllowance: uint40(100)
      })
    );

    vm.expectRevert(abi.encodeWithSignature('NOT_AVAILABLE()'));
    vm.prank(owner);
    _delegate.mint(beneficiary, valueSent);
  }

  function testJBTieredNFTRewardDelegate_mint_revertIfCallerIsNotOwner() external {
    address caller = address(123456);
    vm.assume(caller != owner);

    vm.prank(caller);
    vm.expectRevert(abi.encodePacked('Ownable: caller is not the owner'));
    delegate.mint(beneficiary, 100);
  }

  function testJBTieredNFTRewardDelegate_burn_burnIfCallerIsOwner() external {
    uint256 valueSent = 500;
    // First tier floor is 10 and last tier is 1000
    vm.assume(valueSent >= 10 && valueSent <= 2000);
    vm.prank(owner);
    uint256 tokenId = delegate.mint(beneficiary, valueSent);
    uint256 theoreticalTiers = valueSent <= 100 ? (valueSent / 10) : 10;

    // Check: correct event
    vm.expectEmit(true, false, false, true, address(delegate));
    emit Burn(tokenId, beneficiary, owner);

    // Actual call
    vm.prank(owner);
    delegate.burn(beneficiary, tokenId);

    // Check: allowance left - back to the original one (tiers are 1-indexed)
    assertEq(
      delegate.tiers()[theoreticalTiers - 1].remainingAllowance,
      tiers[theoreticalTiers - 1].remainingAllowance
    );

    // Check: beneficiary balance
    assertEq(delegate.totalOwnerBalance(beneficiary), 0);
  }

  function testJBTieredNFTRewardDelegate_burn_revertIfCallerIsNotOwner() external {
    address caller = address(123456);

    vm.assume(caller != owner);
    vm.prank(owner);
    uint256 tokenId = delegate.mint(beneficiary, 100);

    vm.prank(caller);
    vm.expectRevert(abi.encodePacked('Ownable: caller is not the owner'));
    delegate.burn(beneficiary, tokenId);
  }

  function testJBTieredNFTRewardDelegate_burn_revertIfTokenIsNotExisting() external {
    uint256 _tokenId = 123;
    vm.prank(owner);
    vm.expectRevert(abi.encodePacked('NOT_MINTED'));
    delegate.burn(beneficiary, _tokenId);
  }

  // If the amount payed is below the contributionFloor to receive an NFT the pay should not revert
  function testJBTieredNFTRewardDelegate_payParams_doesNotRevertOnAmountBelowContributionFloor()
    external
  {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    // The calldata is correct but the 'msg.sender' is not the '_expectedCaller'
    vm.prank(mockTerminalAddress);
    delegate.payParams(
      JBPayParamsData(
        IJBPaymentTerminal(mockTerminalAddress),
        msg.sender,
        JBTokenAmount(
          mockContributionToken,
          tiers[0].contributionFloor - 1, // 1 wei below the minimum amount
          0,
          0
        ),
        projectId,
        0,
        msg.sender,
        0,
        0,
        '',
        new bytes(0)
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  function testJBTieredNFTRewardDelegate_payParams_revertIfNotTerminalOfProjectId() external {
    address _terminal = address(6969);
    vm.assume(_terminal != mockTerminalAddress);

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
      abi.encode(false)
    );

    // The caller is the _expectedCaller however the terminal in the calldata is not correct
    vm.prank(mockTerminalAddress);
    vm.expectRevert(abi.encodeWithSignature('INVALID_PAYMENT_EVENT()'));
    delegate.payParams(
      JBPayParamsData(
        IJBPaymentTerminal(_terminal),
        msg.sender,
        JBTokenAmount(address(0), 0, 0, 0),
        projectId,
        0,
        msg.sender,
        0,
        0,
        '',
        new bytes(0)
      )
    );
  }

  function testJBTieredNFTRewardDelegate_payParams_revertIfCallerNotExpectedCaller() external {
    address _terminal = address(6969);
    vm.assume(_terminal != mockTerminalAddress);

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    // The calldata is correct but the 'msg.sender' is not the '_expectedCaller'
    vm.prank(_terminal);
    vm.expectRevert(abi.encodeWithSignature('INVALID_PAYMENT_EVENT()'));
    delegate.payParams(
      JBPayParamsData(
        IJBPaymentTerminal(mockTerminalAddress),
        msg.sender,
        JBTokenAmount(address(0), 0, 0, 0),
        projectId,
        0,
        msg.sender,
        0,
        0,
        '',
        new bytes(0)
      )
    );
  }

  // Internal helpers

  // JBNFTRewardTier Array comparison
  function assertEq(JBNFTRewardTier[] memory first, JBNFTRewardTier[] memory second) private {
    assertEq(first.length, second.length);

    for (uint256 i; i < first.length; i++) {
      assertEq(first[i].contributionFloor, second[i].contributionFloor);
      assertEq(first[i].idCeiling, second[i].idCeiling);
      assertEq(first[i].remainingAllowance, second[i].remainingAllowance);
      assertEq(first[i].initialAllowance, second[i].initialAllowance);
    }
  }
}

contract ForTest_JBTieredLimitedNFTRewardDataSource is JBTieredLimitedNFTRewardDataSource {
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _baseUri,
    string memory _contractUri,
    address _expectedCaller,
    address _owner,
    address _contributionToken,
    JBNFTRewardTier[] memory __tiers
  )
    JBTieredLimitedNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _baseUri,
      _contractUri,
      _expectedCaller,
      _owner,
      _contributionToken,
      __tiers
    )
  {}

  function setTier(uint256 index, JBNFTRewardTier calldata newTier) public {
    _tiers[index] = newTier;
  }
}
