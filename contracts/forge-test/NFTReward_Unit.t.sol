pragma solidity 0.8.6;

import '../JBTieredLimitedNFTRewardDataSource.sol';
import '../interfaces/IJBTieredLimitedNFTRewardDataSource.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
  using stdStorage for StdStorage;

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

  // The theoretical tokenUri is therefore http://www.null.com/QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz

  JBNFTRewardTierData[] tierData;

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
      tierData.push(
        JBNFTRewardTierData({
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
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_allTiers_returnsAllTiers(uint8 numberOfTiers) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
        })
      );
    }

    // assertEq(_delegate.tiers(), _tierdata);
  }

  function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint16 numberOfTiers)
    public
  {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < numberOfTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(100 - (i + 1)),
          initialQuantity: uint40(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
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

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    // Temp tiers, will get overwritten later
    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false,
      reserveBeneficiary // _shouldMintByDefault
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
          ((totalMinted * reservedRate) / JBConstants.MAX_RESERVED_RATE) - reservedMinted
        );
  }

  function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(
    uint16 numberOfTiers,
    address holder
  ) public {
    vm.assume(numberOfTiers > 0 && numberOfTiers < 30);

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](numberOfTiers);

    for (uint256 i; i < numberOfTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(i + 1),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
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
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
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

  function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNoResolverUsed(address holder)
    external
  {
    vm.assume(holder != address(0));

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    for (uint256 i; i < _tierData.length; i++) {
      _tierData[i] = JBNFTRewardTierData({
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
        _tierData,
        false,
        reserveBeneficiary
      );

    for (uint256 i = 1; i <= _tierData.length; i++) {
      uint256 tokenId = _generateTokenId(i, 1);

      _delegate.ForTest_setOwnerOf(tokenId, holder);

      assertEq(
        _delegate.tokenURI(tokenId),
        'http://www.null.com/QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz'
      );
    }
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
      tierData,
      false, // _shouldMintByDefault
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
      tierData,
      false, // _shouldMintByDefault
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
      tierData,
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    assertEq(_delegate.firstOwnerOf(tokenId), address(0));
  }

  function testJBTieredNFTRewardDelegate_constructor_deployIfTiersSorted(uint8 nbTiers) public {
    vm.assume(nbTiers < 10);

    // Create new tiers array
    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
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
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault
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
    // assertEq(_delegate.tiers(), _tierData);
  }

  // -- Deprecated --
  // function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfTiersNonSorted(
  //   uint8 nbTiers,
  //   uint8 errorIndex
  // ) public {
  //   vm.assume(nbTiers < 20);
  //   vm.assume(errorIndex < nbTiers); // Avoid overflow for the next assume
  //   vm.assume(errorIndex + 1 < nbTiers); // We'll create an error by inverting tiers[i] and [i+1] floor prices

  //   // Create new tiers array
  //   JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);
  //   for (uint256 i; i < nbTiers; i++) {
  //     _tierData[i] = JBNFTRewardTierData({
  //       contributionFloor: uint80(i * 10),
  //       lockedUntil: uint48(0),
  //       remainingQuantity: uint40(100),
  //       initialQuantity: uint40(100),
  //       votingUnits: uint16(0),
  //       reservedRate: uint16(0),
  //       tokenUri: tokenUris[0]
  //     });
  //   }

  //   // Swap the contribution floors
  //   (_tierData[errorIndex].contributionFloor, _tierData[errorIndex + 1].contributionFloor) = (
  //     _tierData[errorIndex + 1].contributionFloor,
  //     _tierData[errorIndex].contributionFloor
  //   );

  //   // Expect the error at i+1 (as the floor is now smaller than i)
  //   vm.expectRevert(abi.encodeWithSignature('INVALID_PRICE_SORT_ORDER()'));
  //   new JBTieredLimitedNFTRewardDataSource(
  //     projectId,
  //     IJBDirectory(mockJBDirectory),
  //     name,
  //     symbol,
  //     IJBTokenUriResolver(mockTokenUriResolver),
  //     contractUri,
  //     baseUri,
  //     owner,
  //     _tierData,
  //     false, // _shouldMintByDefault
  //     reserveBeneficiary
  //   );
  // }

  function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyRemainingQuantity(
    uint8 nbTiers,
    uint8 errorIndex
  ) public {
    vm.assume(nbTiers < 20);
    vm.assume(errorIndex < nbTiers);

    // Create new tiers array
    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);
    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80(i * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: tokenUris[0]
      });
    }

    _tierData[errorIndex].initialQuantity = 0;

    // Expect the error at i+1 (as the floor is now smaller than i)
    vm.expectRevert(abi.encodeWithSignature('NO_QUANTITY()'));
    new JBTieredLimitedNFTRewardDataSource(
      projectId,
      IJBDirectory(mockJBDirectory),
      name,
      symbol,
      IJBTokenUriResolver(mockTokenUriResolver),
      contractUri,
      baseUri,
      owner,
      _tierData,
      false, // _shouldMintByDefault,
      reserveBeneficiary
    );
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_mintReservedToken() public {
    // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
    // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;
    uint256 nbTiers = 3;

    vm.mockCall(
      mockJBProjects,
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(owner)
    );

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](nbTiers);

    // Temp tiers, will get overwritten later (pass the constructor check)
    for (uint256 i; i < nbTiers; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault
      reserveBeneficiary
    );

    for (uint256 i; i < nbTiers; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
        })
      );

      _delegate.ForTest_setReservesMintedFor(i + 1, reservedMinted);
    }

    for (uint256 tier = 1; tier <= nbTiers; tier++) {
      uint256 mintable = _delegate.numberOfReservedTokensOutstandingFor(tier);

      for (uint256 token = 1; token <= mintable; token++) {
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit MintReservedToken(
          _generateTokenId(tier, totalMinted + token),
          tier,
          reserveBeneficiary,
          owner
        );
      }

      vm.prank(owner);
      _delegate.mintReservesFor(tier, mintable);

      // Check balance
      assertEq(_delegate.balanceOf(reserveBeneficiary), mintable * tier);
    }
  }

  function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfNotEnoughReservedLeft() public {
    uint256 initialQuantity = 200;
    uint256 totalMinted = 120;
    uint256 reservedMinted = 1;
    uint256 reservedRate = 4000;

    JBNFTRewardTierData[] memory _tierData = new JBNFTRewardTierData[](10);

    for (uint256 i; i < 10; i++) {
      _tierData[i] = JBNFTRewardTierData({
        contributionFloor: uint80((i + 1) * 10),
        lockedUntil: uint48(0),
        remainingQuantity: uint40(100),
        initialQuantity: uint40(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
      false, // _shouldMintByDefault,
      reserveBeneficiary
    );

    for (uint256 i; i < 10; i++) {
      _delegate.ForTest_setTier(
        i + 1,
        JBNFTRewardTierData({
          contributionFloor: uint80((i + 1) * 10),
          lockedUntil: uint48(0),
          remainingQuantity: uint40(initialQuantity - totalMinted),
          initialQuantity: uint40(initialQuantity),
          votingUnits: uint16(0),
          reservedRate: uint16(reservedRate),
          tokenUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89
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
        JBTokenAmount(JBTokens.ETH, tierData[0].contributionFloor - 1, 0, 0), // 1 wei below the minimum amount
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
  //         JBTokenAmount(JBTokens.ETH, tiers[0].contributionFloor, 0, 0),
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
      assertEq(first[i].data.contributionFloor, second[i].data.contributionFloor);
      // assertEq(first[i].idCeiling, second[i].idCeiling);
      assertEq(first[i].data.remainingQuantity, second[i].data.remainingQuantity);
      assertEq(first[i].data.initialQuantity, second[i].data.initialQuantity);
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
    string memory _baseUri,
    address _owner,
    JBNFTRewardTierData[] memory _tierData,
    bool _shouldMintByDefault,
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
      _tierData,
      _shouldMintByDefault,
      _reserveBeneficiary
    )
  {}

  function ForTest_setTier(uint256 index, JBNFTRewardTierData calldata newTier) public {
    tierData[index] = newTier;
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
