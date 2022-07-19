pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;

  address beneficiary = address(69420);
  address owner = address(42069);
  address mockJBDirectory = address(100);
  address mockJBProjects = address(101);
  address mockTokenUriResolver = address(102);
  address mockContributionToken = address(103);
  address mockTerminalAddress = address(104);

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com';
  string contractUri = 'ipfs://null';

  string[] tokenUris = [
    'http://www.null.com/1',
    'http://www.null.com/2',
    'http://www.null.com/3',
    'http://www.null.com/4',
    'http://www.null.com/5',
    'http://www.null.com/6',
    'http://www.null.com/7',
    'http://www.null.com/8',
    'http://www.null.com/9',
    'http://www.null.com/10'
  ];

  JBNFTRewardTier[] tiers;

  JBTieredLimitedNFTRewardDataSource delegate;

  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    uint256 numRewards,
    address caller
  );

  event MintReservedToken(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    address caller
  );

  function setUp() public {
    vm.label(beneficiary, 'beneficiary');
    vm.label(owner, 'owner');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockContributionToken, 'mockContributionToken');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockContributionToken, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));

    // Create 10 tiers, each with 100 tokens available to mint
    for (uint256 i; i < 10; i++) {
      tiers.push(
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[i]
        })
      );
    }

    delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );
  }

  function testJBTieredNFTRewardDelegate_allTiers_returnsAllTiers(uint8 numberOfTiers) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: 'foo'
        })
      );
    }

    assertEq(_delegate.allTiers(), _tiers);
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint16 numberOfTiers)
    public
  {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(100 - (i + 1)),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: 'foo'
        })
      );
    }

    assertEq(_delegate.totalSupply(), ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_balanceOf_returnsCompleteBalance(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setBalanceOf(holder, i + 1, (i + 1) * 10);
    }

    assertEq(_delegate.balanceOf(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_returnsOutstandingReserved()
    public
  {
    // 120 minted, 1 is reserved -> 119 are non-reserved, therefore there is a max of 119/40 reserved token,
    // rounded up at 3 -> since 1 is minted, 2 more can be
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 40;

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 'foo'
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i; i < 10; i++) assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 2);
  }

  // --------
  function FixThis__JBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_FuzzedreturnsOutstandingReserved(
    uint16 initialQuantity,
    uint16 totalMinted,
    uint16 reservedMinted,
    uint16 reservedRate
  ) public {
    vm.assume(initialQuantity > totalMinted);
    vm.assume(totalMinted > reservedMinted);
    if (reservedRate != 0) vm.assume(totalMinted / reservedRate >= reservedMinted);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false,
      IJBProjects(mockJBProjects) // _shouldMintByDefault
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 'foo'
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    // No reserved token were available
    if (reservedRate == 0)
      for (uint256 i; i < 10; i++)
        assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 0);
    // We need to round up if non reserved minted is less than reserved rate
    else if (totalMinted / reservedRate == 0)
      for (uint256 i; i < 10; i++)
        assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 1);
    // All the reserved token are minted, rest 0 reserved
    else if (reservedMinted == initialQuantity / reservedRate)
      for (uint256 i; i < 10; i++)
        assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 0);
    // non-reserved minted is not a multiple of reserved rate, we'll have to round up
    else if ((totalMinted - reservedMinted) % reservedRate != 0)
      if (reservedMinted == 0)
        // Round up if none has been minted
        for (uint256 i; i < 10; i++)
          assertEq(
            _delegate.numberOfReservedTokensOutstandingFor(i + 1),
            (totalMinted / reservedRate) + 1
          );
      // Some has already been minted
      else
        for (uint256 i; i < 10; i++)
          assertEq(
            _delegate.numberOfReservedTokensOutstandingFor(i + 1),
            ((totalMinted - reservedMinted) / reservedRate) - reservedMinted + 1
          );
    else
      for (uint256 i; i < 10; i++)
        assertEq(
          _delegate.numberOfReservedTokensOutstandingFor(i + 1),
          ((totalMinted - reservedMinted) / reservedRate) - reservedMinted
        );
  }

  function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setBalanceOf(holder, i + 1, 10);
    }

    assertEq(_delegate.getVotingUnits(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_tierIdOfToken_returnsCorrectTierNumber(
    uint8 _tierId,
    uint8 _tokenNumber
  ) external {
    vm.assume(_tierId > 0 && _tokenNumber > 0);
    uint256 tokenId = _generateTokenId(_tierId, _tokenNumber);

    assertEq(delegate.tierIdOfToken(tokenId), _tierId);
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNotMinted(uint256 tokenId)
    external
  {
    // Token not minted -> no URI
    assertEq(delegate.tokenURI(tokenId), '');
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfResolverUsed(
    uint256 tokenId,
    address holder
  ) external {
    vm.assume(holder != address(0));

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    // Mock the URI resolver call
    vm.mockCall(
      mockTokenUriResolver,
      abi.encodeWithSignature('getUri(uint256)', tokenId),
      abi.encode('resolverURI')
    );

    _delegate.ForTest_setOwnerOf(tokenId, holder);

    assertEq(_delegate.tokenURI(tokenId), 'resolverURI');
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNoResolverUsed(
    uint80 tier,
    address holder
  ) external {
    vm.assume(holder != address(0));
    vm.assume(tier > 0 && tier < 30);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](30);

    for (uint256 i; i < _tiers.length; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: uint2str(i + 1)
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(address(0)),
        contractUri,
        owner,
        mockContributionToken,
        _tiers,
        false,
        IJBProjects(mockJBProjects)
      );

    uint256 tokenId = _generateTokenId(tier, 1);

    _delegate.ForTest_setOwnerOf(tokenId, holder);

    assertEq(_delegate.tokenURI(tokenId), uint2str(tier));
  }

  function testJBTieredNFTRewardDelegate_constructor_deployIfTiersSorted(uint8 nbTiers) public {
    vm.assume(nbTiers < 10);

    // Create new tiers array
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    JBTieredLimitedNFTRewardDataSource _delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    // Check: delegate has correct parameters?
    assertEq(_delegate.projectId(), projectId);
    assertEq(address(_delegate.directory()), mockJBDirectory);
    assertEq(_delegate.name(), name);
    assertEq(_delegate.symbol(), symbol);
    assertEq(address(_delegate.tokenUriResolver()), mockTokenUriResolver);
    assertEq(_delegate.contractUri(), contractUri);
    assertEq(_delegate.owner(), owner);
    assertEq(_delegate.contributionToken(), mockContributionToken);
    assertEq(_delegate.allTiers(), _tiers);
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfTiersNonSorted(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
    vm.assume(errorIndex + 1 < nbTiers); // We'll create an error by inverting tiers[i] and [i+1] floor prices

    // Create new tiers array
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    // Swap the contribution floors
    (_tiers[errorIndex].contributionFloor, _tiers[errorIndex + 1].contributionFloor) = (
      _tiers[errorIndex + 1].contributionFloor,
      _tiers[errorIndex].contributionFloor
    );

    // Expect the error at i+1 (as the floor is now smaller than i)
    vm.expectRevert(abi.encodeWithSignature('INVALID_PRICE_SORT_ORDER()'));
    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyRemainingQuantity(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers);

    // Create new tiers array
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128(i * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    // Swap the contribution floors
    _tiers[errorIndex].remainingQuantity = 0;

    // Expect the error at i+1 (as the floor is now smaller than i)
    vm.expectRevert(abi.encodeWithSignature('NO_QUANTITY()'));
    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault,
      IJBProjects(mockJBProjects)
    );
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_mintReservedToken(
    uint16 initialQuantity,
    uint16 totalMinted,
    uint16 reservedMinted,
    uint16 reservedRate,
    uint8 nbTiers
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(reservedRate > 0 && reservedRate <= 100);
    vm.assume(initialQuantity >= totalMinted);
    vm.assume(reservedMinted <= totalMinted);

    // Amount of reserved minted can't be more than the totalMinted and reservedRate would imply
    vm.assume((totalMinted - reservedMinted) / reservedRate > reservedMinted);

    vm.mockCall(
      mockJBProjects,
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      //abi.encodeWithSignature('ownerOf(uint256)(address)', projectId),
      abi.encode(owner)
    );

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);

    // Temp tiers, will get overwritten later (pass the constructor check)
    for (uint256 i; i < nbTiers; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < nbTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 'foo'
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 tier = 1; tier <= nbTiers; tier++) {
      uint256 mintable = _delegate.numberOfReservedTokensOutstandingFor(tier);

      // Limit the amount at 10
      mintable = mintable <= 10 ? mintable : 10;

      for (uint256 token = 1; token <= mintable; token++) {
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit MintReservedToken(_generateTokenId(tier, totalMinted + token), tier, owner, owner);
      }

      vm.prank(owner);
      _delegate.mintReservesFor(tier, mintable);

      // Check balance
      assertEq(_delegate.balanceOf(owner), mintable * tier);
    }
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfNotEnoughReservedLeft(
    uint16 initialQuantity,
    uint16 totalMinted,
    uint16 reservedMinted,
    uint16 reservedRate
  ) public {
    vm.assume(reservedRate > 0 && reservedRate <= 100);
    vm.assume(initialQuantity >= totalMinted);
    vm.assume(reservedMinted <= totalMinted);

    // Amount of reserved minted can't be more than the totalMinted and reservedRate would imply
    vm.assume((totalMinted - reservedMinted) / reservedRate > reservedMinted);

    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](10);

    for (uint256 i; i < 10; i++) {
      _tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 'foo'
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      owner,
      mockContributionToken,
      _tiers,
      false, // _shouldMintByDefault,
      IJBProjects(mockJBProjects)
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTier({
          contributionFloor: uint128((i + 1) * 10),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 'foo'
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i = 1; i <= 10; i++) {
      // Get the amount that we can mint successfully
      uint256 amount = _delegate.numberOfReservedTokensOutstandingFor(i);
      // Increase it by 1 to cause an error
      amount++;

      vm.expectRevert(abi.encodeWithSignature('INSUFFICIENT_RESERVES()'));
      vm.prank(owner);
      _delegate.mintReservesFor(i, amount);
    }
  }

  // --------------------------------

  // If the amount payed is below the contributionFloor to receive an NFT the pay should not revert
  function testJBTieredNFTRewardDelegate_didPay_doesNotRevertOnAmountBelowContributionFloor()
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
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(mockContributionToken, tiers[0].contributionFloor - 1, 0, 0), // 1 wei below the minimum amount
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  // function testJBTieredNFTRewardDelegate_didPay_revertIfAllowanceRunsOut() external {
  //   // Create 10 tiers, each with 10 tokens available to mint
  //   for (uint256 i; i < 10; i++) {
  //     tiers.push(JBNFTRewardTier({
  //       contributionFloor: uint128((i + 1) * 10),
  //       remainingQuantity: uint40(10),
  //       initialQuantity: uint40(10),
  //       tokenUri: tokenUris[i]
  //     }));
  //   }

  //   // Mock the directory call
  //   vm.mockCall(
  //     address(mockJBDirectory),
  //     abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
  //     abi.encode(true)
  //   );

  //   uint256 _supplyLeft = tiers[0].initialQuantity;
  //   while (true) {
  //     uint256 _totalSupplyBeforePay = delegate.totalSupply();

  //     // If there is no supply left this should revert
  //     if (_supplyLeft == 0) {
  //       vm.expectRevert(abi.encodeWithSignature('NOT_AVAILABLE()'));
  //     }

  //     uint256 _metadata;
  //     _metadata |= 1 << 32; // 1 reward
  //     _metadata |= 1 << 40; // tier 1

  //     // Perform the pay
  //     vm.prank(mockTerminalAddress);
  //     delegate.didPay(
  //       JBDidPayData(
  //         msg.sender,
  //         projectId,
  //         0,
  //         JBTokenAmount(mockContributionToken, tiers[0].contributionFloor, 0, 0),
  //         0,
  //         msg.sender,
  //         false,
  //         '',
  //         abi.encode(_metadata)
  //       )
  //     );

  //     // Make sure if there was no supply left there was no NFT minted
  //     if (_supplyLeft == 0) {
  //       assertEq(delegate.totalSupply(), _totalSupplyBeforePay);
  //       break;
  //     } else {
  //       assertEq(delegate.totalSupply(), _totalSupplyBeforePay + 1);
  //     }

  //     --_supplyLeft;
  //   }
  // }

  function testJBTieredNFTRewardDelegate_didPay_revertIfCallerIsNotATerminalOfProjectId(
    address _terminal
  ) external {
    vm.assume(_terminal != mockTerminalAddress);

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
      abi.encode(false)
    );

    // The caller is the _expectedCaller however the terminal in the calldata is not correct
    vm.prank(_terminal);
    vm.expectRevert(abi.encodeWithSignature('INVALID_PAYMENT_EVENT()'));
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(address(0), 0, 0, 0),
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );
  }

  // ----------------
  // Internal helpers
  // ----------------

  // JBNFTRewardTier Array comparison
  function assertEq(JBNFTRewardTier[] memory first, JBNFTRewardTier[] memory second) private {
    assertEq(first.length, second.length);

    for (uint256 i; i < first.length; i++) {
      assertEq(first[i].contributionFloor, second[i].contributionFloor);
      // assertEq(first[i].idCeiling, second[i].idCeiling);
      assertEq(first[i].remainingQuantity, second[i].remainingQuantity);
      assertEq(first[i].initialQuantity, second[i].initialQuantity);
    }
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

  function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return '0';
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }
}

// ForTest to manually set some internalt nested values
contract ForTest_JBTieredLimitedNFTRewardDataSource is JBTieredLimitedNFTRewardDataSource {
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    address _owner,
    address _contributionToken,
    JBNFTRewardTier[] memory __tiers,
    bool _shouldMintByDefault,
    IJBProjects _projects
  )
    JBTieredLimitedNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _contractUri,
      _owner,
      _contributionToken,
      __tiers,
      _shouldMintByDefault,
      _projects
    )
  {}

  function ForTest_setTier(uint256 index, JBNFTRewardTier calldata newTier) public {
    tiers[index] = newTier;
  }

  function ForTest_setBalanceOf(
    address holder,
    uint256 tier,
    uint256 balance
  ) public {
    tierBalanceOf[holder][tier] = balance;
  }

  function ForTest_setReservesMintedFor(uint256 tier, uint256 amount) public {
    numberOfReservesMintedFor[tier] = amount;
  }

  function ForTest_setOwnerOf(uint256 tokenId, address _owner) public {
    _owners[tokenId] = _owner;
  }
}
