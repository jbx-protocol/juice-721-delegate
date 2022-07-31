pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import './utils/AccessJBLib.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;
  AccessJBLib internal _accessJBLib;

  address beneficiary = address(bytes20(keccak256('beneficiary')));
  address owner = address(bytes20(keccak256('owner')));
  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
  address mockJBDirectory = address(bytes20(keccak256('mockJBDirectory')));
  address mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
  address mockTerminalAddress = address(bytes20(keccak256('mockTerminalAddress')));
  address mockJBProjects = address(bytes20(keccak256('mockJBProjects')));

  uint256 projectId = 69;

  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com/';
  string contractUri = 'ipfs://null';

  // NodeJS: function con(hash) { Buffer.from(bs58.decode(hash).slice(2)).toString('hex') }
  // JS;  0x${bs58.decode(hash).slice(2).toString('hex')})

  bytes32[] tokenUris = [
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0xf5d60fc6f462f6176982833f5e2ca222a2ced265fa94e4ce1c477d74910250ed),
    bytes32(0x4258512cfb09993d9f3613a59ffc592a5593abf3c06ed57a22656c5fbca4de23),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f83e358c8),
    bytes32(0xae7035a8ef12433adbf4a55f2faabecff3446276fdbc6f6209e6bba25ee358c8),
    bytes32(0xae7035a8ef1242fc4b803a9284453843f278307462311f8b8b90fddfcbe358c8),
    bytes32(0xae824fb9f7de128f66cb5e224e4f8c65f37c479ee6ec7193c8741d6f997f5a18),
    bytes32(0xae7035a8f8d14617dd6d904265fe7d84a493c628385ffba7016d6463c852e8c8),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f74adbbf7),
    bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf51c38098273db23452d955758c8)
  ];

  string[] theoricHashes = [
    'QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz',
    'QmetHutWQPz3qfu5jhTi1bqbRZXt8zAJaqqxkiJoJCX9DN',
    'QmSodj3RSrXKPy3WRFSPz8HRDVyRdrBtjxBfoiWBgtGugN',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5atSTeoKJkcXe2R7typcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5atSTeoKJKSQSDFcgdmcvPvLJJkh2jd4cDZeM1wnFgK',
    'Qma5rtytgfdgzrg4345RFGdfbzert345rfgvs5YRtSTkcX',
    'Qma5atSTkcXe2R7gdmcvPvLJJkh2234234QcDZeM1wnFgK',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1ZERze',
    'Qma5atSTeoKJkcXe2R7gdmcvPvLJLkh2jd4cDZeM1wnFgK'
  ];

  JBNFTRewardTierParams[] tierParams;

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

  event SetReservedTokenBeneficiary(address indexed beneficiary, address caller);

  function setUp() public {
    _accessJBLib = new AccessJBLib();
    vm.label(beneficiary, 'beneficiary');
    vm.label(owner, 'owner');
    vm.label(reserveBeneficiary, 'reserveBeneficiary');
    vm.label(mockJBDirectory, 'mockJBDirectory');
    vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
    vm.label(mockTerminalAddress, 'mockTerminalAddress');
    vm.label(mockJBProjects, 'mockJBProjects');

    vm.etch(mockJBDirectory, new bytes(0x69));
    vm.etch(mockTokenUriResolver, new bytes(0x69));
    vm.etch(mockTerminalAddress, new bytes(0x69));
    vm.etch(mockJBProjects, new bytes(0x69));

    // Create 10 tiers, each with 100 tokens available to mint
    for (uint256 i; i < 10; i++) {
      tierParams.push(
        JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
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
      baseUri,
      owner,
      tierParams,
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_tiers_returnsAllTiers(uint8 numberOfTiers) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](numberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tiers[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        encodedIPFSUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    // Avoid having difference due to the reverse order of the tiers array in _addTierParams
    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(i + 1, _tierParams[i]);
    }

    assertTrue(_isIn(_delegate.tiers(), _tiers));
    assertTrue(_isIn(_tiers, _delegate.tiers()));
  }

  function testJBTieredNFTRewardDelegate_tier_returnsTheGivenTier(
    uint8 numberOfTiers,
    uint8 givenTier
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](numberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    // Avoid having difference due to the reverse order of the tiers array in _addTierParams
    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(i + 1, _tierParams[i]);
    }

    // Check: correct tier, if exist?
    if (givenTier <= numberOfTiers && givenTier != 0)
      assertEq(_delegate.tier(givenTier), _tiers[givenTier - 1]);
    else
      assertEq( // empty tier if not?
        _delegate.tier(givenTier),
        JBNFTRewardTier({id: givenTier, data: JBNFTRewardTierParams(0, 0, 0, 0, 0, 0, 0)})
      );
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint16 numberOfTiers)
    public
  {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100 - (i + 1)),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
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

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setBalanceOf(holder, i + 1, (i + 1) * 10);
    }

    assertEq(_delegate.balanceOf(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
  }

  function testJBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_returnsOutstandingReserved()
    public
  {
    // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
    // meaning there are 47.6 total reserved to mint (-> rounding up 48), 1 being already minted, 47 are outstanding
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i; i < 10; i++)
      assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 47);
  }

  // --------
  function TOFIX_JBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_FuzzedreturnsOutstandingReserved(
    uint16 initialQuantity,
    uint16 totalMinted,
    uint16 reservedMinted,
    uint16 reservedRate
  ) public {
    vm.assume(initialQuantity > totalMinted);
    vm.assume(totalMinted > reservedMinted);
    if (reservedRate != 0)
      vm.assume(
        uint256((totalMinted - reservedMinted) * reservedRate) / JBConstants.MAX_RESERVED_RATE >=
          reservedMinted
      );

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );
      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    // No reserved token were available
    if (reservedRate == 0 || initialQuantity == 0)
      for (uint256 i; i < 10; i++)
        assertEq(_delegate.numberOfReservedTokensOutstandingFor(i + 1), 0);
    else if (
      reservedMinted != 0 && (totalMinted * reservedRate) / JBConstants.MAX_RESERVED_RATE > 0
    )
      for (uint256 i; i < 10; i++)
        assertEq(
          _delegate.numberOfReservedTokensOutstandingFor(i + 1),
          ((totalMinted - reservedMinted * reservedRate) / JBConstants.MAX_RESERVED_RATE)
        );
  }

  function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
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
        baseUri,
        owner,
        tierParams,
        reserveBeneficiary
      );

    // Mock the URI resolver call
    vm.mockCall(
      mockTokenUriResolver,
      abi.encodeWithSelector(IJBTokenUriResolver.getUri.selector, tokenId),
      abi.encode('resolverURI')
    );

    _delegate.ForTest_setOwnerOf(tokenId, holder);

    assertEq(_delegate.tokenURI(tokenId), 'resolverURI');
  }

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNoResolverUsed(address holder)
    external
  {
    vm.assume(holder != address(0));

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](10);

    for (uint256 i; i < _tierParams.length; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(address(0)),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i = 1; i <= _tierParams.length; i++) {
      uint256 tokenId = _generateTokenId(i, 1);

      _delegate.ForTest_setOwnerOf(tokenId, holder);

      assertEq(
        _delegate.tokenURI(tokenId),
        string(abi.encodePacked(baseUri, theoricHashes[i - 1]))
      );
    }
  }

  function testJBTieredNFTRewardDelegate_redemptionWeightOf_returnsCorrectWeightAsFloorsCumSum(
    uint16 numberOfTiers,
    uint8 firstTier,
    uint8 lastTier
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);
    vm.assume(firstTier <= lastTier);
    vm.assume(lastTier <= numberOfTiers);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    uint256 _maxNumberOfTiers = (numberOfTiers * (numberOfTiers + 1)) / 2; // "tier" token per tier -> max == numberOfTiers!
    uint256[] memory _tierToGetWeightOf = new uint256[](_maxNumberOfTiers);

    uint256 _iterator;
    uint256 _theoreticalWeight;
    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      if (i >= firstTier && i < lastTier) {
        for (uint256 j; j <= i; j++) {
          _tierToGetWeightOf[_iterator] = _generateTokenId(i + 1, j + 1); // "tier" tokens per tier
          _iterator++;
        }
        _theoreticalWeight += (i + 1) * (i + 1) * 10; //floor is 10
      }
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierData,
        reserveBeneficiary
      );

    assertEq(_delegate.redemptionWeightOf(_tierToGetWeightOf), _theoreticalWeight);
  }

  function testJBTieredNFTRewardDelegate_totalRedemptionWeight_returnsCorrectTotalWeightAsFloorsCumSum(
    uint16 numberOfTiers
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    uint256 _theoreticalWeight;

    // Temp value for the constructor
    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierData,
        reserveBeneficiary
      );

    for (uint256 i = 1; i <= numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i,
        JBNFTRewardTierData({
          contributionFloor: uint80(i * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(10 * i - 5 * i),
          initialQuantity: uint40(10 * i),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
        })
      );

      _theoreticalWeight += (10 * i - 5 * i) * i * 10;
    }

    assertEq(_delegate.totalRedemptionWeight(), _theoreticalWeight);
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnCurrentOwnerIfFirstOwner(
    uint256 tokenId,
    address _owner
  ) public {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        tierParams,
        reserveBeneficiary
      );

    _delegate.ForTest_setOwnerOf(tokenId, _owner);
    assertEq(_delegate.firstOwnerOf(tokenId), _owner);
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnFirstOwnerIfOwnerChanged(
    uint256 tokenId,
    address _owner,
    address _previousOwner
  ) public {
    vm.assume(_owner != _previousOwner);
    vm.assume(_previousOwner != address(0));

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        tierParams,
        reserveBeneficiary
      );

    _delegate.ForTest_setOwnerOf(tokenId, _owner);
    _delegate.ForTest_setFirstOwnerOf(tokenId, _previousOwner);

    assertEq(_delegate.firstOwnerOf(tokenId), _previousOwner);
  }

  function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnAddressZeroIfNotMinted(
    uint256 tokenId
  ) public {
    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        tierParams,
        reserveBeneficiary
      );

    assertEq(_delegate.firstOwnerOf(tokenId), address(0));
  }

  function testJBTieredNFTRewardDelegate_constructor_deployIfNoEmptyInitialQuantity(uint8 nbTiers)
    public
  {
    vm.assume(nbTiers < 10);

    // Create new tiers array
    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](nbTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);

    for (uint256 i; i < nbTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    JBTieredLimitedNFTRewardDataSource _delegate = new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierParams,
      reserveBeneficiary
    );

    // Check: delegate has correct parameters?
    assertEq(_delegate.projectId(), projectId);
    assertEq(address(_delegate.directory()), mockJBDirectory);
    assertEq(_delegate.name(), name);
    assertEq(_delegate.symbol(), symbol);
    assertEq(address(_delegate.tokenUriResolver()), mockTokenUriResolver);
    assertEq(_delegate.contractUri(), contractUri);
    assertEq(_delegate.owner(), owner);
    assertTrue(_isIn(_delegate.tiers(), _tiers)); // Order is not insured
    assertTrue(_isIn(_tiers, _delegate.tiers()));
  }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyInitialQuantity(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers);

    // Create new tiers array
    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    _tierParams[errorIndex].initialQuantity = 0;

    // Expect the error at i+1 (as the floor is now smaller than i)
    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.NO_QUANTITY.selector)
    );
    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierParams,
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_mintReservedTokenForTheCorrectBeneficiary(
    uint8 _offset
  ) public {
    // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
    // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;
    uint256 nbTiers = 5;

    vm.assume(_offset < nbTiers);

    vm.mockCall(
      mockJBProjects,
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(owner)
    );

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](nbTiers);

    // Temp tiers, will get overwritten later (pass the constructor check)
    for (uint256 i; i < nbTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i],
        reservedTokenBeneficiary: owner
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < nbTiers; i++) {
      if (i != _offset)
        _delegate.ForTest_setTier(
          i + 1,
          JBNFTRewardTierParams({
            contributionFloor: uint80((i + 1) * 10),
            lockedUntil: uint48(0),
            remainingQuantity: uint40(initialQuantity - totalMinted),
            initialQuantity: uint40(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            tokenUri: tokenUris[i],
            reservedTokenBeneficiary: address(0)
          })
        ); // Set a tier-specific reserved beneficiary
      else
        _delegate.ForTest_setTier(
          i + 1,
          JBNFTRewardTierParams({
            contributionFloor: uint80((i + 1) * 10),
            lockedUntil: uint48(0),
            remainingQuantity: uint40(initialQuantity - totalMinted),
            initialQuantity: uint40(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            tokenUri: tokenUris[i],
            reservedTokenBeneficiary: owner
          })
        );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    uint256 ownerTokenCounter;
    uint256 reserveBeneficiaryTokenCounter;
    for (uint256 tier = 1; tier <= nbTiers; tier++) {
      uint256 mintable = _delegate.numberOfReservedTokensOutstandingFor(tier);

      for (uint256 token = 1; token <= mintable; token++) {
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit MintReservedToken(
          _generateTokenId(tier, totalMinted + token),
          tier,
          tier == (_offset + 1) ? owner : reserveBeneficiary,
          owner
        );
      }

      vm.prank(owner);
      _delegate.mintReservesFor(tier, mintable);

      if (tier == (_offset + 1)) ownerTokenCounter += mintable;
      else reserveBeneficiaryTokenCounter += mintable;
    }
    // Check balance
    assertEq(_delegate.balanceOf(owner), ownerTokenCounter);
    assertEq(_delegate.balanceOf(reserveBeneficiary), reserveBeneficiaryTokenCounter);
  }

  function testJBTieredNFTRewardDelegate_setReservedTokenBeneficiary() public {
    testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(
      address(bytes20(keccak256('newReserveBeneficiary')))
    );
    testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(
      address(bytes20(keccak256('anotherNewReserveBeneficiary')))
    );
  }

  function testJBTieredNFTRewardDelegate_setReservedTokenBeneficiaryFuzzed(address _newBeneficiary)
    public
  {
    // Make sure the beneficiary is actually changing
    vm.assume(_newBeneficiary != delegate.reservedTokenBeneficiary());

    vm.expectEmit(true, true, true, true, address(delegate));
    emit SetReservedTokenBeneficiary(_newBeneficiary, owner);

    vm.prank(owner);
    delegate.setReservedTokenBeneficiary(_newBeneficiary);

    assertEq(delegate.reservedTokenBeneficiary(), _newBeneficiary);
  }

  function testJBTieredNFTRewardDelegate_setReservedTokenBeneficiary_revertsOnNonOwner(
    address _sender,
    address _newBeneficiary
  ) public {
    // Make sure the sender is not the owner
    vm.assume(_sender != owner);

    vm.expectRevert('Ownable: caller is not the owner');

    vm.prank(_sender);
    delegate.setReservedTokenBeneficiary(_newBeneficiary);
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfNotEnoughReservedLeft() public {
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](10);

    for (uint256 i; i < 10; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[i]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: tokenUris[i]
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 i = 1; i <= 10; i++) {
      // Get the amount that we can mint successfully
      uint256 amount = _delegate.numberOfReservedTokensOutstandingFor(i);
      // Increase it by 1 to cause an error
      amount++;

      vm.expectRevert(
        abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.INSUFFICIENT_RESERVES.selector)
      );
      vm.prank(owner);
      _delegate.mintReservesFor(i, amount);
    }
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 15);
    vm.assume(numberTiersToAdd > 0 && numberTiersToAdd < 15);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    JBNFTRewardTierParams[] memory _tierParamsToAdd = new JBNFTRewardTierParams[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierParamsToAdd[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierParamsToAdd[i]});
    }

    vm.prank(owner);
    _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));

    JBNFTRewardTier[] memory _storedTiers = _delegate.tiers();

    // Check: Expected number of tiers?
    assertEq(_storedTiers.length, _tiers.length + _tiersAdded.length);

    // Check: Are all tiers in the new tiers (unsorted)?
    assertTrue(_isIn(_tiers, _storedTiers));
    assertTrue(_isIn(_tiersAdded, _storedTiers));
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_removeTiers(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToRemove
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 15);
    vm.assume(numberTiersToRemove > 0 && numberTiersToRemove < initialNumberOfTiers);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    _delegate.tiers();

    uint256[] memory _tiersToRemove = new uint256[](numberTiersToRemove);

    JBNFTRewardTierParams[] memory _tierParamsRemaining = new JBNFTRewardTierParams[](
      initialNumberOfTiers - numberTiersToRemove
    );
    JBNFTRewardTier[] memory _tiersRemaining = new JBNFTRewardTier[](
      initialNumberOfTiers - numberTiersToRemove
    );

    for (uint256 i; i < initialNumberOfTiers; i++) {
      if (i >= numberTiersToRemove) {
        uint256 _arrayIndex = i - numberTiersToRemove;
        _tierParamsRemaining[_arrayIndex] = JBNFTRewardTierParams({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          tokenUri: tokenUris[0]
        });

        _tiersRemaining[_arrayIndex] = JBNFTRewardTier({
          id: i + 1,
          data: _tierParamsRemaining[_arrayIndex]
        });
      } else _tiersToRemove[i] = i + 1;
    }

    vm.prank(owner);
    _delegate.adjustTiers(new JBNFTRewardTierParams[](0), _tiersToRemove);

    JBNFTRewardTier[] memory _storedTiers = _delegate.tiers();

    // Check expected number of tiers remainings
    assertEq(_storedTiers.length, _tiers.length - numberTiersToRemove);

    // Check that all the remaining tiers still exist
    assertTrue(_isIn(_tiersRemaining, _storedTiers));

    // Check that none of the removed tiers still exist
    for (uint256 i; i < _tiersToRemove.length; i++) {
      JBNFTRewardTier[] memory _removedTier = new JBNFTRewardTier[](1);
      _removedTier[0] = _tiers[i];
      assertTrue(!_isIn(_removedTier, _storedTiers));
    }
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithVotingPower(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    JBNFTRewardTierParams[] memory _tierParamsToAdd = new JBNFTRewardTierParams[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierParamsToAdd[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierParamsToAdd[i]});
    }

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.VOTING_UNITS_NOT_ALLOWED.selector)
    );
    vm.prank(owner);
    _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithReservedRate(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    JBNFTRewardTierParams[] memory _tierParamsToAdd = new JBNFTRewardTierParams[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierParamsToAdd[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i + 1),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierParamsToAdd[i]});
    }

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.RESERVED_RATE_NOT_ALLOWED.selector)
    );
    vm.prank(owner);
    _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
  }

  function testJBTieredNFTRewardDelegate_adjustTiers_revertIfEmptyQuantity(
    uint8 initialNumberOfTiers,
    uint8 numberTiersToAdd
  ) public {
    // Include adding X new tiers when 0 preexisting ones
    vm.assume(initialNumberOfTiers < 30);
    vm.assume(numberTiersToAdd > 0);

    JBNFTRewardTierParams[] memory _tierParams = new JBNFTRewardTierParams[](initialNumberOfTiers);
    JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](initialNumberOfTiers);

    for (uint256 i; i < initialNumberOfTiers; i++) {
      _tierParams[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(i),
        tokenUri: tokenUris[0]
      });

      _tiers[i] = JBNFTRewardTier({id: i + 1, data: _tierParams[i]});
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierParams,
        reserveBeneficiary
      );

    JBNFTRewardTierParams[] memory _tierParamsToAdd = new JBNFTRewardTierParams[](numberTiersToAdd);
    JBNFTRewardTier[] memory _tiersAdded = new JBNFTRewardTier[](numberTiersToAdd);

    for (uint256 i; i < numberTiersToAdd; i++) {
      _tierParamsToAdd[i] = JBNFTRewardTierParams({
        contributionFloor: uint80((i + 1) * 100),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(0),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });

      _tiersAdded[i] = JBNFTRewardTier({id: _tiers.length + (i + 1), data: _tierParamsToAdd[i]});
    }

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.NO_QUANTITY.selector)
    );
    vm.prank(owner);
    _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
  }

  // ----------------
  //        Pay
  // ----------------

  // If the amount payed is below the contributionFloor to receive an NFT the pay should not revert if no metadata passed
  function testJBTieredNFTRewardDelegate_didPay_doesNotRevertOnAmountBelowContributionFloorIfNoMetadata()
    external
  {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(JBTokens.ETH, tierParams[0].contributionFloor - 1, 0, 0), // 1 wei below the minimum amount
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

  // If the amount is above contribution floor, a tier is passed but the bool to prevent mint is true, do not mint
  function testJBTieredNFTRewardDelegate_didPay_doesNotMintIfMetadataDeactivateMint() external {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint = true;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](1);
    _tierIdsToMint[0] = 1;

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(JBTokens.ETH, tierParams[0].contributionFloor + 10, 0, 0), // 10 above the floor
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  // If the amount is above contribution floor and a tier is passed, mint as many corresponding tier as possible
  function testJBTieredNFTRewardDelegate_didPay_mintCorrectTier() external {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](3);
    _tierIdsToMint[0] = 1;
    _tierIdsToMint[1] = 1;
    _tierIdsToMint[2] = 2;

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(
          JBTokens.ETH,
          tierParams[0].contributionFloor * 2 + tierParams[1].contributionFloor,
          0,
          0
        ),
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure a new NFT was minted
    assertEq(_totalSupplyBeforePay + 3, delegate.totalSupply());

    // Correct tier has been minted?
    assertEq(delegate.ownerOf(_generateTokenId(1, 1)), msg.sender);
    assertEq(delegate.ownerOf(_generateTokenId(1, 2)), msg.sender);
    assertEq(delegate.ownerOf(_generateTokenId(2, 1)), msg.sender);
  }

  function testJBTieredNFTRewardDelegate_didPay_mintBestTierIfNonePassed(uint8 _amount) external {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](0);

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(JBTokens.ETH, _amount, 0, 0),
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure a new NFT was minted if amount >= contribution floor
    if (_amount >= tierParams[0].contributionFloor) {
      assertEq(_totalSupplyBeforePay + 1, delegate.totalSupply());

      // Correct tier has been minted?
      uint256 highestTier = _amount > 100 ? 10 : _amount / 10;
      uint256 tokenId = _generateTokenId(highestTier, 1);
      assertEq(delegate.ownerOf(tokenId), msg.sender);
    } else assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  // If the tier has been removed, revert
  function testJBTieredNFTRewardDelegate_didPay_revertIfTierRemoved() external {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](3);
    _tierIdsToMint[0] = 1;
    _tierIdsToMint[1] = 1;
    _tierIdsToMint[2] = 2;

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    uint256[] memory _toRemove = new uint256[](1);
    _toRemove[0] = 1;

    vm.prank(owner);
    delegate.adjustTiers(new JBNFTRewardTierParams[](0), _toRemove);

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.TIER_REMOVED.selector)
    );
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(
          JBTokens.ETH,
          tierParams[0].contributionFloor * 2 + tierParams[1].contributionFloor,
          0,
          0
        ),
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  function testJBTieredNFTRewardDelegate_didPay_revertIfNonExistingTier(uint8 _invalidTier)
    external
  {
    vm.assume(_invalidTier > tierParams.length);

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](1);
    _tierIdsToMint[0] = _invalidTier;

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    uint256[] memory _toRemove = new uint256[](1);
    _toRemove[0] = 1;

    vm.prank(owner);
    delegate.adjustTiers(new JBNFTRewardTierParams[](0), _toRemove);

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.INVALID_TIER.selector)
    );
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(
          JBTokens.ETH,
          tierParams[0].contributionFloor * 2 + tierParams[1].contributionFloor,
          0,
          0
        ),
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  // If the amount is not enought ot cover all the tiers requested, revert
  function testJBTieredNFTRewardDelegate_didPay_revertIfAmountTooLow() external {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _totalSupplyBeforePay = delegate.totalSupply();

    bool _dontMint;
    bool _expectMintFromExtraFunds;
    bool _dontOverspend;
    uint8[] memory _tierIdsToMint = new uint8[](3);
    _tierIdsToMint[0] = 1;
    _tierIdsToMint[1] = 1;
    _tierIdsToMint[2] = 2;

    bytes memory _metadata = abi.encode(
      bytes32(0),
      type(IJBNFTRewardDataSource).interfaceId,
      _dontMint,
      _expectMintFromExtraFunds,
      _dontOverspend,
      _tierIdsToMint
    );

    vm.expectRevert(
      abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.INSUFFICIENT_AMOUNT.selector)
    );
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(
          JBTokens.ETH,
          tierParams[0].contributionFloor * 2 + tierParams[1].contributionFloor - 1,
          0,
          0
        ),
        0,
        msg.sender,
        false,
        '',
        _metadata
      )
    );

    // Make sure no new NFT was minted
    assertEq(_totalSupplyBeforePay, delegate.totalSupply());
  }

  function testJBTieredNFTRewardDelegate_didPay_revertIfAllowanceRunsOutInParticularTier()
    external
  {
    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    uint256 _supplyLeft = tierParams[0].initialQuantity;
    while (true) {
      uint256 _totalSupplyBeforePay = delegate.totalSupply();

      // If there is no supply left this should revert
      if (_supplyLeft == 0) {
        vm.expectRevert(abi.encodeWithSelector(JBTieredLimitedNFTRewardDataSource.OUT.selector));
      }

      bool _dontMint;
      bool _expectMintFromExtraFunds;
      bool _dontOverspend = true;
      uint8[] memory tierSelected = new uint8[](1);
      tierSelected[0] = 1;

      bytes memory _metadata = abi.encode(
        bytes32(0),
        type(IJBNFTRewardDataSource).interfaceId,
        _dontMint,
        _expectMintFromExtraFunds,
        _dontOverspend,
        tierSelected
      );

      // Perform the pay
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, tierParams[0].contributionFloor, 0, 0),
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );

      // Make sure if there was no supply left there was no NFT minted
      if (_supplyLeft == 0) {
        assertEq(delegate.totalSupply(), _totalSupplyBeforePay);
        break;
      } else {
        assertEq(delegate.totalSupply(), _totalSupplyBeforePay + 1);
      }

      --_supplyLeft;
    }
  }

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
    vm.expectRevert(abi.encodeWithSelector(JBNFTRewardDataSource.INVALID_PAYMENT_EVENT.selector));
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

  function testJBTieredNFTRewardDelegate_didPay_doNotMintIfNotUsingCorrectToken(address token)
    external
  {
    vm.assume(token != delegate.contributionToken());

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    // The caller is the _expectedCaller however the terminal in the calldata is not correct
    vm.prank(mockTerminalAddress);
    delegate.didPay(
      JBDidPayData(
        msg.sender,
        projectId,
        0,
        JBTokenAmount(token, 0, 0, 0),
        0,
        msg.sender,
        false,
        '',
        new bytes(0)
      )
    );

    // Check: nothing has been minted
    assertEq(delegate.totalSupply(), 0);
  }

  // ----------------
  //    Redemption
  // ----------------

  function testJBTieredNFTRewardDelegate_redeemParams_returnsCorrectAmount() external {
    uint256 _overflow = 10e18;
    uint256 _redemptionRate = 4000; // 40%

    uint256 _weight;
    uint256 _totalWeight;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp for constructor
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierData,
        reserveBeneficiary
      );

    // Set 10 tiers, with half supply minted for each
    for (uint256 i = 1; i <= 10; i++) {
      _delegate.ForTest_setTier(
        i,
        JBNFTRewardTierData({
          contributionFloor: uint80(i * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(10 * i - 5 * i),
          initialQuantity: uint40(10 * i),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
        })
      );

      _totalWeight += (10 * i - 5 * i) * i * 10;
    }

    // Redeem based on holding 1 NFT in each of the 5 first tiers
    uint256[] memory _tokenList = new uint256[](5);

    for (uint256 i; i < 5; i++) {
      _delegate.ForTest_setOwnerOf(i + 1, beneficiary);
      _tokenList[i] = i + 1;
      _weight += (i + 1) * 10;
    }

    (uint256 reclaimAmount, string memory memo, IJBRedemptionDelegate _returnedDelegate) = _delegate
      .redeemParams(
        JBRedeemParamsData({
          terminal: IJBPaymentTerminal(address(0)),
          holder: beneficiary,
          projectId: projectId,
          currentFundingCycleConfiguration: 0,
          tokenCount: 0,
          totalSupply: 0,
          overflow: _overflow,
          reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
          useTotalOverflow: true,
          redemptionRate: _redemptionRate,
          ballotRedemptionRate: 0,
          memo: 'plz gib',
          metadata: abi.encode(_tokenList)
        })
      );

    // Portion of the overflow accessible (pro rata weight held)
    uint256 _base = PRBMath.mulDiv(_overflow, _weight, _totalWeight);

    uint256 _claimableOverflow = PRBMath.mulDiv(
      _base,
      _redemptionRate +
        PRBMath.mulDiv(_weight, _accessJBLib.MAX_RESERVED_RATE() - _redemptionRate, _totalWeight),
      _accessJBLib.MAX_RESERVED_RATE()
    );

    assertEq(reclaimAmount, _claimableOverflow);
    assertEq(memo, 'plz gib');
    assertEq(address(_returnedDelegate), address(_delegate));
  }

  function testJBTieredNFTRewardDelegate_redeemParams_returnsZeroAmountIfReservedRateIsZero()
    external
  {
    uint256 _overflow = 10e18;
    uint256 _redemptionRate = 0;

    uint256 _weight;
    uint256 _totalWeight;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp for constructor
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierData,
        reserveBeneficiary
      );

    // Set 10 tiers, with half supply minted for each
    for (uint256 i = 1; i <= 10; i++) {
      _delegate.ForTest_setTier(
        i,
        JBNFTRewardTierData({
          contributionFloor: uint80(i * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(10 * i - 5 * i),
          initialQuantity: uint40(10 * i),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
        })
      );

      _totalWeight += (10 * i - 5 * i) * i * 10;
    }

    // Redeem based on holding 1 NFT in each of the 5 first tiers
    uint256[] memory _tokenList = new uint256[](5);

    for (uint256 i; i < 5; i++) {
      _delegate.ForTest_setOwnerOf(i + 1, beneficiary);
      _tokenList[i] = i + 1;
      _weight += (i + 1) * (i + 1) * 10;
    }

    (uint256 reclaimAmount, string memory memo, IJBRedemptionDelegate _returnedDelegate) = _delegate
      .redeemParams(
        JBRedeemParamsData({
          terminal: IJBPaymentTerminal(address(0)),
          holder: beneficiary,
          projectId: projectId,
          currentFundingCycleConfiguration: 0,
          tokenCount: 0,
          totalSupply: 0,
          overflow: _overflow,
          reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
          useTotalOverflow: true,
          redemptionRate: _redemptionRate,
          ballotRedemptionRate: 0,
          memo: 'plz gib',
          metadata: abi.encode(_tokenList)
        })
      );

    assertEq(reclaimAmount, 0);
    assertEq(memo, 'plz gib');
    assertEq(address(_returnedDelegate), address(_delegate));
  }

  function testJBTieredNFTRewardDelegate_redeemParams_returnsPartOfOverflowOwnedIfRedemptionRateIsMaximum()
    external
  {
    uint256 _overflow = 10e18;
    uint256 _redemptionRate = _accessJBLib.MAX_RESERVED_RATE(); // 40%

    uint256 _weight;
    uint256 _totalWeight;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp for constructor
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        _tierData,
        reserveBeneficiary
      );

    // Set 10 tiers, with half supply minted for each
    for (uint256 i = 1; i <= 10; i++) {
      _delegate.ForTest_setTier(
        i,
        JBNFTRewardTierData({
          contributionFloor: uint80(i * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(10 * i - 5 * i),
          initialQuantity: uint40(10 * i),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: tokenUris[0]
        })
      );

      _totalWeight += (10 * i - 5 * i) * i * 10;
    }

    // Redeem based on holding 1 NFT in each of the 5 first tiers
    uint256[] memory _tokenList = new uint256[](5);

    for (uint256 i; i < 5; i++) {
      _delegate.ForTest_setOwnerOf(_generateTokenId(i + 1, 1), beneficiary);
      _tokenList[i] = _generateTokenId(i + 1, 1);
      _weight += (i + 1) * 10;
    }

    (uint256 reclaimAmount, string memory memo, IJBRedemptionDelegate _returnedDelegate) = _delegate
      .redeemParams(
        JBRedeemParamsData({
          terminal: IJBPaymentTerminal(address(0)),
          holder: beneficiary,
          projectId: projectId,
          currentFundingCycleConfiguration: 0,
          tokenCount: 0,
          totalSupply: 0,
          overflow: _overflow,
          reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
          useTotalOverflow: true,
          redemptionRate: _redemptionRate,
          ballotRedemptionRate: 0,
          memo: 'plz gib',
          metadata: abi.encode(_tokenList)
        })
      );

    // Portion of the overflow accessible (pro rata weight held)
    uint256 _base = PRBMath.mulDiv(_overflow, _weight, _totalWeight);

    assertEq(reclaimAmount, _base);
    assertEq(memo, 'plz gib');
    assertEq(address(_returnedDelegate), address(_delegate));
  }

  function testJBTieredNFTRewardDelegate_redeemParams_revertIfNonZeroTokenCount(uint256 _tokenCount)
    external
  {
    vm.assume(_tokenCount > 0);

    vm.expectRevert(abi.encodeWithSelector(JBNFTRewardDataSource.UNEXPECTED.selector));

    delegate.redeemParams(
      JBRedeemParamsData({
        terminal: IJBPaymentTerminal(address(0)),
        holder: beneficiary,
        projectId: projectId,
        currentFundingCycleConfiguration: 0,
        tokenCount: _tokenCount,
        totalSupply: 0,
        overflow: 100,
        reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
        useTotalOverflow: true,
        redemptionRate: 100,
        ballotRedemptionRate: 0,
        memo: '',
        metadata: new bytes(0)
      })
    );
  }

  function testJBTieredNFTRewardDelegate_didRedeem_burnRedeemedNFT(uint8 _numberOfNFT) external {
    address _holder = address(bytes20(keccak256('_holder')));

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        tierData,
        reserveBeneficiary
      );

    uint256[] memory _tokenList = new uint256[](_numberOfNFT);

    for (uint256 i; i < _numberOfNFT; i++) {
      _delegate.ForTest_setOwnerOf(i + 1, _holder);
      _tokenList[i] = i + 1;
    }

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    vm.prank(mockTerminalAddress);

    _delegate.didRedeem(
      JBDidRedeemData({
        holder: _holder,
        projectId: projectId,
        currentFundingCycleConfiguration: 1,
        projectTokenCount: 0,
        reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
        beneficiary: payable(_holder),
        memo: 'thy shall redeem',
        metadata: abi.encode(_tokenList)
      })
    );
  }

  function testJBTieredNFTRewardDelegate_didRedeem_revertIfNotCorrectProjectId(
    uint8 _wrongProjectId
  ) external {
    vm.assume(_wrongProjectId != projectId);
    address _holder = address(bytes20(keccak256('_holder')));

    uint256[] memory _tokenList = new uint256[](1);
    _tokenList[0] = 1;

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    vm.expectRevert(
      abi.encodeWithSelector(JBNFTRewardDataSource.INVALID_REDEMPTION_EVENT.selector)
    );
    vm.prank(mockTerminalAddress);
    delegate.didRedeem(
      JBDidRedeemData({
        holder: _holder,
        projectId: _wrongProjectId,
        currentFundingCycleConfiguration: 1,
        projectTokenCount: 0,
        reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
        beneficiary: payable(_holder),
        memo: 'thy shall redeem',
        metadata: abi.encode(_tokenList)
      })
    );
  }

  function testJBTieredNFTRewardDelegate_didRedeem_revertIfCallerIsNotATerminalOfTheProject()
    external
  {
    address _holder = address(bytes20(keccak256('_holder')));

    uint256[] memory _tokenList = new uint256[](1);
    _tokenList[0] = 1;

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(false)
    );

    vm.expectRevert(
      abi.encodeWithSelector(JBNFTRewardDataSource.INVALID_REDEMPTION_EVENT.selector)
    );
    vm.prank(mockTerminalAddress);
    delegate.didRedeem(
      JBDidRedeemData({
        holder: _holder,
        projectId: projectId,
        currentFundingCycleConfiguration: 1,
        projectTokenCount: 0,
        reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
        beneficiary: payable(_holder),
        memo: 'thy shall redeem',
        metadata: abi.encode(_tokenList)
      })
    );
  }

  function testJBTieredNFTRewardDelegate_didRedeem_RevertIfWrongHolder(
    address _wrongHolder,
    uint8 tokenId
  ) external {
    address _holder = address(bytes20(keccak256('_holder')));
    vm.assume(_holder != _wrongHolder);
    vm.assume(tokenId != 0);

    ForTest_JBTieredLimitedNFTRewardDataSource _delegate = new ForTest_JBTieredLimitedNFTRewardDataSource(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        baseUri,
        owner,
        tierData,
        reserveBeneficiary
      );

    _delegate.ForTest_setOwnerOf(tokenId, _holder);

    uint256[] memory _tokenList = new uint256[](1);
    _tokenList[0] = tokenId;

    // Mock the directory call
    vm.mockCall(
      address(mockJBDirectory),
      abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
      abi.encode(true)
    );

    vm.expectRevert(abi.encodeWithSelector(JBNFTRewardDataSource.UNAUTHORIZED.selector));
    vm.prank(mockTerminalAddress);
    _delegate.didRedeem(
      JBDidRedeemData({
        holder: _wrongHolder,
        projectId: projectId,
        currentFundingCycleConfiguration: 1,
        projectTokenCount: 0,
        reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 0, currency: 0}),
        beneficiary: payable(_wrongHolder),
        memo: 'thy shall redeem',
        metadata: abi.encode(_tokenList)
      })
    );
  }

  // ----------------
  // Internal helpers
  // ----------------

  // JBNFTRewardTier comparison
  function assertEq(JBNFTRewardTier memory first, JBNFTRewardTier memory second) private {
    assertEq(first.id, second.id);
    assertEq(first.data.contributionFloor, second.data.contributionFloor);
    assertEq(first.data.lockedUntil, second.data.lockedUntil);
    assertEq(first.data.remainingQuantity, second.data.remainingQuantity);
    assertEq(first.data.initialQuantity, second.data.initialQuantity);
    assertEq(first.data.votingUnits, second.data.votingUnits);
    assertEq(first.data.reservedRate, second.data.reservedRate);
    assertEq(first.data.tokenUri, second.data.tokenUri);
  }

  // JBNFTRewardTier Array comparison
  function assertEq(JBNFTRewardTier[] memory first, JBNFTRewardTier[] memory second) private {
    assertEq(first.length, second.length);

    for (uint256 i; i < first.length; i++) {
      assertEq(first[i].id, second[i].id);
      assertEq(first[i].data.contributionFloor, second[i].data.contributionFloor);
      assertEq(first[i].data.lockedUntil, second[i].data.lockedUntil);
      assertEq(first[i].data.remainingQuantity, second[i].data.remainingQuantity);
      assertEq(first[i].data.initialQuantity, second[i].data.initialQuantity);
      assertEq(first[i].data.votingUnits, second[i].data.votingUnits);
      assertEq(first[i].data.reservedRate, second[i].data.reservedRate);
      assertEq(first[i].data.tokenUri, second[i].data.tokenUri);
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

  // Check if every elements from smol are in bigg
  function _isIn(JBNFTRewardTier[] memory smol, JBNFTRewardTier[] memory bigg)
    private
    returns (bool)
  {
    // Cannot be oversized
    if (smol.length > bigg.length) {
      emit log('_isIn: smol too big');
      return false;
    }

    if (smol.length == 0) return true;

    uint256 count;

    // Iterate on every smol elements
    for (uint256 smolIter; smolIter < smol.length; smolIter++) {
      // Compare it with every bigg element until...
      for (uint256 biggIter; biggIter < bigg.length; biggIter++) {
        // ... the same element is found -> break to go to the next smol element
        if (_compareTiers(smol[smolIter], bigg[biggIter])) {
          count += smolIter + 1; // 1-indexed, as the length
          break;
        }
      }
    }

    // Insure all the smoll indexes have been iterated on (ie we've seen (smoll.length)! elements)
    if (count == (smol.length * (smol.length + 1)) / 2) return true;
    else {
      emit log('_isIn: incomplete inclusion');
      return false;
    }
  }

  function _compareTiers(JBNFTRewardTier memory first, JBNFTRewardTier memory second)
    private
    returns (bool)
  {
    if (
      first.id == second.id &&
      first.data.contributionFloor == second.data.contributionFloor &&
      first.data.lockedUntil == second.data.lockedUntil &&
      first.data.remainingQuantity == second.data.remainingQuantity &&
      first.data.initialQuantity == second.data.initialQuantity &&
      first.data.votingUnits == second.data.votingUnits &&
      first.data.reservedRate == second.data.reservedRate &&
      first.data.tokenUri == second.data.tokenUri
    ) return true;
    else {
      emit log('_compareTiers:mismatch');
      console.log(first.id, second.id);
      console.log(first.data.contributionFloor, second.data.contributionFloor);
      console.log(first.data.lockedUntil, second.data.lockedUntil);
      console.log(first.data.remainingQuantity, second.data.remainingQuantity);
      console.log(first.data.initialQuantity, second.data.initialQuantity);
      console.log(first.data.votingUnits, second.data.votingUnits);
      console.log(first.data.reservedRate, second.data.reservedRate);
      console.log(uint256(first.data.tokenUri), uint256(second.data.tokenUri));
      return false;
    }
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
    string memory _baseUri,
    address _owner,
    JBNFTRewardTierParams[] memory _tierParams,
    address _reserveBeneficiary
  )
    JBTieredLimitedNFTRewardDataSource(
      _projectId,
      _directory,
      _name,
      _symbol,
      _tokenUriResolver,
      _contractUri,
      _baseUri,
      _owner,
      _tierParams,
      _reserveBeneficiary
    )
  {}

  function ForTest_setTier(uint256 index, JBNFTRewardTierParams calldata newTier) public {
    tierParams[index] = newTier;
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

  function ForTest_setFirstOwnerOf(uint256 tokenId, address _owner) public {
    _firstOwnerOf[tokenId] = _owner;
  }
}
