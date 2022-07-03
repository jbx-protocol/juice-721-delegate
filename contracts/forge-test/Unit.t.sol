pragma solidity 0.8.6;

import '../JBTieredNFTRewardDelegate.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;

  address caller = address(69420);
  address owner = address(42069);
  address mockJBDirectory = address(1);
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

  function setUp() public {
    vm.label(caller, 'caller');
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
          remainingAllowance: uint40(99),
          initialAllowance: uint40(100)
        })
      );
    }

    delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IToken721UriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      tiers
    );
  }

  function testJBTieredNFTRewardDelegate_deploy_deployIfTiersSorted(uint8 nbTiers) public {
    vm.assume(nbTiers < 20);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48( i * 100),
        remainingAllowance: uint40(99),
        initialAllowance: uint40(100)
      });
    }

    JBTieredLimitedNFTRewardDataSource _delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IToken721UriResolver(mockTokenUriResolver),
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

  function testJBTieredNFTRewardDelegate_deployer_revertDeploymentIfPriceTiersNonSorted(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
    vm.assume(errorIndex + 1 < nbTiers); // We'll create an error between i and i+1

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48(i * 100),
        remainingAllowance: uint40(99),
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
      IToken721UriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      _tiers
    );
  }

  function testJBTieredNFTRewardDelegate_deployer_revertDeploymentIfIdCeilingsNonSorted(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
    vm.assume(errorIndex + 1 < nbTiers); // We'll create an error between i and i+1

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i = 1; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        idCeiling: uint48(i * 100),
        remainingAllowance: uint40(99),
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
      IToken721UriResolver(mockTokenUriResolver),
      baseUri,
      contractUri,
      mockTerminalAddress,
      owner,
      mockContributionToken,
      _tiers
    );
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsCorrectTotalSuuply() external {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IToken721UriResolver(mockTokenUriResolver),
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

  function testJBTieredNFTRewardDelegate_tierNumberOfToken_returnsCorrectTierNumber(uint8 tokenId)
    external
  {
    // Tiers are from 1 to 10, with 100 token per tier

    // If in an existing tier, should return it
    if (tokenId <= 10 * 100)
      assertEq(delegate.tierNumberOfToken(tokenId), (tokenId / 100) + 1);
      // If outside of existing tiers, should return 0&@@
    else assertEq(delegate.tierNumberOfToken(tokenId), 0);
  }

  function testJBTieredNFTRewardDelegate_mint_mintIfCallerIsOwner(uint8 valueSent) external {
    // First tier floor is 10 and last tier is 1000
    vm.assume(valueSent >= 10 && valueSent <= 2000);

    vm.prank(owner);
    delegate.mint(caller, valueSent);

    // todo check event

    assertEq(delegate.totalOwnerBalance(caller), 1);
  }

  function testJBTieredNFTRewardDelegate_mint_revertIfNoAllowanceLeft(uint8 valueSent) external {
  }

  function testJBTieredNFTRewardDelegate_mint_revertIfCallerIsNotOwner(uint8 valueSent) external {
  }

  function testJBTieredNFTRewardDelegate_burn_burnIfCallerIsOwner(uint8 valueSent) external {

// check new balance
// check new remaining allowance
// check event
  }

function testJBTieredNFTRewardDelegate_burn_revertIfCallerIsNotOwner(uint8 valueSent) external {

    
  }

    function testJBTieredNFTRewardDelegate_burn_revertIfTokenIsNotOwnerd(uint8 valueSent) external {

    
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
    IToken721UriResolver _tokenUriResolver,
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
