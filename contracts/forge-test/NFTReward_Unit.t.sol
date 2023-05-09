pragma solidity ^0.8.16;

import '../JBTiered721DelegateDeployer.sol';
import '../JBTiered721Delegate.sol';
import '../JBTiered721DelegateStore.sol';
import '../interfaces/IJBTiered721Delegate.sol';
import '../structs/JBBitmapWord.sol';
import './utils/AccessJBLib.sol';
import 'forge-std/Test.sol';

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBFundingCycleMetadataResolver.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol';
import '@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol';

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatable.sol';

contract TestJBTieredNFTRewardDelegate is Test {
    using stdStorage for StdStorage;
    AccessJBLib internal _accessJBLib;
    address beneficiary = address(bytes20(keccak256('beneficiary')));
    address owner = address(bytes20(keccak256('owner')));
    address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
    address mockJBDirectory = address(bytes20(keccak256('mockJBDirectory')));
    address mockJBFundingCycleStore = address(bytes20(keccak256('mockJBFundingCycleStore')));
    address mockTokenUriResolver = address(0); //bytes20(keccak256('mockTokenUriResolver')));
    address mockTerminalAddress = address(bytes20(keccak256('mockTerminalAddress')));
    address mockJBProjects = address(bytes20(keccak256('mockJBProjects')));
    address mockJBOperatorStore = address(bytes20(keccak256('mockJBOperatorStore')));
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
    JB721TierParams[] tiers;
    JBTiered721Delegate delegate;
    JBTiered721Delegate noGovernanceOrigin; // noGovernanceOrigin
    JBDelegatesRegistry delegatesRegistry;
    address delegate_i = address(bytes20(keccak256('delegate_implementation')));
    event Mint(
      uint256 indexed tokenId,
      uint256 indexed tierId,
      address indexed beneficiary,
      uint256 totalAmountContributed,
      address caller
    );
    event MintReservedToken(
      uint256 indexed tokenId,
      uint256 indexed tierId,
      address indexed beneficiary,
      address caller
    );
    event SetDefaultReservedTokenBeneficiary(address indexed beneficiary, address caller);
    event AddTier(uint256 indexed tierId, JB721TierParams tier, address caller);
    event RemoveTier(uint256 indexed tierId, address caller);
    event CleanTiers(address indexed nft, address caller);
    event AddCredits(
      uint256 indexed changeAmount,
      uint256 indexed newTotalCredits,
      address indexed account,
      address caller
    );
    event UseCredits(
      uint256 indexed changeAmount,
      uint256 indexed newTotalCredits,
      address indexed account,
      address caller
    );
    function setUp() public {
      _accessJBLib = new AccessJBLib();
      vm.label(beneficiary, 'beneficiary');
      vm.label(owner, 'owner');
      vm.label(reserveBeneficiary, 'reserveBeneficiary');
      vm.label(mockJBDirectory, 'mockJBDirectory');
      vm.label(mockJBFundingCycleStore, 'mockJBFundingCycleStore');
      vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
      vm.label(mockTerminalAddress, 'mockTerminalAddress');
      vm.label(mockJBProjects, 'mockJBProjects');
      vm.etch(mockJBDirectory, new bytes(0x69));
      vm.etch(mockJBFundingCycleStore, new bytes(0x69));
      vm.etch(mockTokenUriResolver, new bytes(0x69));
      vm.etch(mockTerminalAddress, new bytes(0x69));
      vm.etch(mockJBProjects, new bytes(0x69));
      // Create 10 tiers, each with 100 tokens available to mint
      for (uint256 i; i < 10; i++) {
        tiers.push(
          JB721TierParams({
            price: uint104((i + 1) * 10),
            initialQuantity: uint32(100),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            reservedTokenBeneficiary: reserveBeneficiary,
            encodedIPFSUri: tokenUris[i],
            category: uint24(100),
            allowManualMint: false,
            shouldUseReservedTokenBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: false
          })
        );
      }
      vm.mockCall(
        mockJBFundingCycleStore,
        abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
        abi.encode(
          JBFundingCycle({
            number: 1,
            configuration: block.timestamp,
            basedOn: 0,
            start: block.timestamp,
            duration: 600,
            weight: 10e18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0)),
            metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
              JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                  allowSetTerminals: false,
                  allowSetController: false,
                  pauseTransfers: false
                }),
                reservedRate: 5000, //50%
                redemptionRate: 5000, //50%
                ballotRedemptionRate: 5000,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(0),
                metadata: 0x00
              })
            )
          })
        )
      );
      vm.mockCall(mockJBDirectory, abi.encodeWithSelector(IJBDirectory.projects.selector), abi.encode(mockJBProjects));
      vm.mockCall(mockJBDirectory, abi.encodeWithSelector(IJBOperatable.operatorStore.selector), abi.encode(mockJBProjects));
      noGovernanceOrigin = new JBTiered721Delegate(IJBProjects(mockJBProjects), IJBOperatorStore(mockJBOperatorStore));
      JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(IJBProjects(mockJBProjects), IJBOperatorStore(mockJBOperatorStore));
      delegatesRegistry = new JBDelegatesRegistry();
      JBTiered721DelegateDeployer jbDelegateDeployer = new JBTiered721DelegateDeployer(
        onchainGovernance,
        noGovernanceOrigin,
        delegatesRegistry
      );
      JBDeployTiered721DelegateData memory delegateData = JBDeployTiered721DelegateData(
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        owner,
        JB721PricingParams({tiers: tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
        address(0),
        new JBTiered721DelegateStore(),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        }),
        JB721GovernanceType.NONE
      );
      delegate = JBTiered721Delegate(address(jbDelegateDeployer.deployDelegateFor(
        projectId,
        delegateData,
        IJBDirectory(mockJBDirectory)
      )));
    }
    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiers(uint256 numberOfTiers) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](numberOfTiers);
      for (uint256 i; i < numberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16((i + 1) * 10),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      assertTrue(_isIn(_delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers), _tiers));
      assertTrue(_isIn(_tiers, _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers)));
    }
    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiersWithResolver(uint256 numberOfTiers) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](numberOfTiers);
      address _mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
      for (uint256 i; i < numberOfTiers; i++) {
        uint256 _zeroToken = _generateTokenId(i + 1, 0);
        string memory uri = string(abi.encodePacked('resolverURI', _zeroToken));
        // Mock the URI resolver call
        vm.mockCall(
          _mockTokenUriResolver,
          abi.encodeWithSelector(IJBTokenUriResolver.getUri.selector, _zeroToken),
          abi.encode(uri) 
        );
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16((i + 1) * 10),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: uri
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(_mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      assertTrue(_isIn(_delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers), _tiers));
      assertTrue(_isIn(_tiers, _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers)));
    }
    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiers_coverage() public {
      testJBTieredNFTRewardDelegate_tiers_returnsAllTiers(5);
    }
    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiersExcludingRemovedOnes(
      uint256 numberOfTiers,
      uint256 firstRemovedTier,
      uint256 secondRemovedTier
    ) public {
      numberOfTiers = bound(numberOfTiers, 1, 30);
      firstRemovedTier = bound(firstRemovedTier, 1, numberOfTiers);
      secondRemovedTier = bound(secondRemovedTier, 1, numberOfTiers);
      vm.assume(firstRemovedTier != secondRemovedTier);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](numberOfTiers);
      JB721Tier[] memory _nonRemovedTiers = new JB721Tier[](numberOfTiers - 2);
       // to avoid stack too deep
      {
      uint256 j;
      for (uint256 i; i < numberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
        if (i != firstRemovedTier - 1 && i != secondRemovedTier - 1) {
          _nonRemovedTiers[j] = _tiers[i];
          j++;
        }
      }
      }
      // to avoid stack too deep
      {
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      _delegate.test_store().ForTest_setIsTierRemoved(address(_delegate), firstRemovedTier);
      _delegate.test_store().ForTest_setIsTierRemoved(address(_delegate), secondRemovedTier);
      // Check: tier array returned is resized
      assertEq(
        _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers).length,
        numberOfTiers - 2
      );
      // Check: all and only the non-removed tiers are in the tier array returned
      assertTrue(
        _isIn(_delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers), _nonRemovedTiers)
      );
      assertTrue(
        _isIn(_nonRemovedTiers, _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), 0, numberOfTiers))
      );
      }
    }
    function testJBTieredNFTRewardDelegate_tier_returnsTheGivenTier(
      uint256 numberOfTiers,
      uint16 givenTier
    ) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](numberOfTiers);
      for (uint256 i; i < numberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Avoid having difference due to the reverse order of the tiers array in _addTierData
      for (uint256 i; i < numberOfTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104(_tierParams[i].price),
           remainingQuantity: uint32(_tierParams[i].initialQuantity),
            initialQuantity: uint32(_tierParams[i].initialQuantity),
            votingUnits: uint16(_tierParams[i].votingUnits),
            reservedRate: uint16(_tierParams[i].reservedRate),
            category: uint24(_tierParams[i].category),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
      }
      // Check: correct tier, if exist?
      if (givenTier <= numberOfTiers && givenTier != 0)
        assertEq(_delegate.test_store().tierOf(address(_delegate), givenTier), _tiers[givenTier - 1]);
      else
        assertEq( // empty tier if not?
          _delegate.test_store().tierOf(address(_delegate), givenTier),
          JB721Tier({
            id: givenTier,
            price: 0,
            remainingQuantity: 0,
            initialQuantity: 0,
            votingUnits: 0,
            reservedRate: 0,
            reservedTokenBeneficiary: address(0),
            encodedIPFSUri: bytes32(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            resolvedUri: ""
          })
        );
    }
    function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint256 numberOfTiers)
      public
    {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
      for (uint256 i; i < numberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < numberOfTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(100 - (i + 1)),
            initialQuantity: uint32(100),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
          })
        );
      }
      assertEq(
        _delegate.test_store().totalSupply(address(_delegate)),
        ((numberOfTiers * (numberOfTiers + 1)) / 2)
      );
    }
    function testJBTieredNFTRewardDelegate_balanceOf_returnsCompleteBalance(
      uint256 numberOfTiers,
      address holder
    ) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tiers = new JB721TierParams[](numberOfTiers);
      for (uint256 i; i < numberOfTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < numberOfTiers; i++) {
        _delegate.test_store().ForTest_setBalanceOf(address(_delegate), holder, i + 1, (i + 1) * 10);
      }
      assertEq(_delegate.balanceOf(holder), 10 * ((numberOfTiers * (numberOfTiers + 1)) / 2));
    }
    function testJBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_returnsOutstandingReserved()
      public
    {
      // 120 are minted, 10 out of these are reserved, meaning 110 non-reserved are minted. The reservedRate is
      // 9 (1 reserved token for every 9 non-reserved minted) -> total reserved is 13 (  ceil(110 / 9)), still 3 to mint
      uint256 initialQuantity = 200;
      uint256 totalMinted = 120;
      uint256 reservedMinted = 10;
      uint256 reservedRate = 9;
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      // Temp tiers, will get overwritten later
      for (uint256 i; i < 10; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      for (uint256 i; i < 10; i++)
        assertEq(
          _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), i + 1),
          3
        );
    }
    function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(
      uint256 numberOfTiers,
      address holder
    ) public {
      numberOfTiers = bound(numberOfTiers, 1, 30);
      JB721TierParams[] memory _tiers = new JB721TierParams[](numberOfTiers);
      for (uint256 i; i < numberOfTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i), // Include a 0 voting unit tier
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < numberOfTiers; i++) {
        _delegate.test_store().ForTest_setBalanceOf(address(_delegate), holder, i + 1, 10);
      }
      assertEq(
        _delegate.test_store().votingUnitsOf(address(_delegate), holder),
        10 * ((numberOfTiers * (numberOfTiers - 1)) / 2) // (numberOfTiers-1)! * 10
      );
    }
    function testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits() public {
      testJBTieredNFTRewardDelegate_getvotingUnits_returnsTheTotalVotingUnits(5, beneficiary);
    }
    function testJBTieredNFTRewardDelegate_tierIdOfToken_returnsCorrectTierNumber(
      uint16 _tierId,
      uint16 _tokenNumber
    ) public {
      vm.assume(_tierId > 0 && _tokenNumber > 0);
      uint256 tokenId = _generateTokenId(_tierId, _tokenNumber);
      assertEq(delegate.store().tierOfTokenId(address(delegate), tokenId).id, _tierId);
    }
    function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfResolverUsed(
      uint256 tokenId,
      address holder
    ) public {
      vm.assume(holder != address(0));
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      address _mockTokenUriResolver = address(bytes20(keccak256('mockTokenUriResolver')));
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(_mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Mock the URI resolver call
      vm.mockCall(
        _mockTokenUriResolver,
        abi.encodeWithSelector(IJBTokenUriResolver.getUri.selector, tokenId),
        abi.encode('resolverURI')
      );
      _delegate.ForTest_setOwnerOf(tokenId, holder);
      assertEq(_delegate.tokenURI(tokenId), 'resolverURI');
    }
    function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfNoResolverUsed(bool isMinted, address holder)
      public
    {
      // If IsMinted is true then we need a valid holder address, otherwise 0 is allowed
      vm.assume(!isMinted || holder != address(0));
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      for (uint256 i; i < _tiers.length; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(address(0)),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i = 1; i <= _tiers.length; i++) {
        uint256 tokenId = _generateTokenId(i, 1);
        if(isMinted)
          _delegate.ForTest_setOwnerOf(tokenId, holder);
        assertEq(
          _delegate.tokenURI(tokenId),
          string(abi.encodePacked(baseUri, theoricHashes[i - 1]))
        );
      }
    }
    function testJBTieredNFTRewardDelegate_setEncodedIPFSUriOf_returnsCorrectUriIfEncodedAdded()
      public
    {
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      for (uint256 i; i < _tiers.length; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(address(0)),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      uint256 tokenId = _generateTokenId(1, 1);
      _delegate.ForTest_setOwnerOf(tokenId, address(123));
      vm.prank(owner);
      _delegate.setMetadata("", "", IJBTokenUriResolver(address(0)), 1, tokenUris[1]);
      assertEq(
        _delegate.tokenURI(tokenId),
        string(abi.encodePacked(baseUri, theoricHashes[1]))
      );
    }
    function testJBTieredNFTRewardDelegate_redemptionWeightOf_returnsCorrectWeightAsFloorsCumSum(
      uint256 numberOfTiers,
      uint16 firstTier,
      uint16 lastTier
    ) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      vm.assume(firstTier <= lastTier);
      vm.assume(lastTier <= numberOfTiers);
      JB721TierParams[] memory _tiers = new JB721TierParams[](numberOfTiers);
      uint256 _maxNumberOfTiers = (numberOfTiers * (numberOfTiers + 1)) / 2; // "tier amount" of token mintable per tier -> max == numberOfTiers!
      uint256[] memory _tierToGetWeightOf = new uint256[](_maxNumberOfTiers);
      uint256 _iterator;
      uint256 _theoreticalWeight;
      for (uint256 i; i < numberOfTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        if (i >= firstTier && i < lastTier) {
          for (uint256 j; j <= i; j++) {
            _tierToGetWeightOf[_iterator] = _generateTokenId(i + 1, j + 1); // "tier" tokens per tier
            _iterator++;
          }
          _theoreticalWeight += (i + 1) * (i + 1) * 10; //floor is 10
        }
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      assertEq(
        _delegate.test_store().redemptionWeightOf(address(_delegate), _tierToGetWeightOf),
        _theoreticalWeight
      );
    }
    function testJBTieredNFTRewardDelegate_totalRedemptionWeight_returnsCorrectTotalWeightAsFloorsCumSum(
      uint256 numberOfTiers
    ) public {
      numberOfTiers = bound(numberOfTiers, 0, 30);
      JB721TierParams[] memory _tiers = new JB721TierParams[](numberOfTiers);
      uint256 _theoreticalWeight;
      // Temp value for the constructor
      for (uint256 i; i < numberOfTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i = 1; i <= numberOfTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i,
          JBStored721Tier({
            price: uint104(i * 10),
           remainingQuantity: uint32(10 * i - 5 * i),
            initialQuantity: uint32(10 * i),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
          })
        );
        _theoreticalWeight += (10 * i - 5 * i) * i * 10;
      }
      assertEq(_delegate.test_store().totalRedemptionWeight(address(_delegate)), _theoreticalWeight);
    }
    function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnCurrentOwnerIfFirstOwner(
      uint256 tokenId,
      address _owner
    ) public {
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      _delegate.ForTest_setOwnerOf(tokenId, _owner);
      assertEq(_delegate.firstOwnerOf(tokenId), _owner);
    }
    function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnFirstOwnerIfOwnerChanged(
      address _owner,
      address _previousOwner
    ) public {
      vm.assume(_owner != _previousOwner);
      vm.assume(_owner != address(0));
      vm.assume(_previousOwner != address(0));
      vm.mockCall(
        mockJBProjects,
        abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
        abi.encode(owner)
      );
      JB721TierParams[] memory _tiers = new JB721TierParams[](1);
      uint16[] memory _tiersToMint = new uint16[](1);

      _tiers[0] = JB721TierParams({
        price: uint104(10),
        initialQuantity: uint32(100),
        votingUnits: uint16(0),
        reservedRate: uint16(0),
        reservedTokenBeneficiary: reserveBeneficiary,
        encodedIPFSUri: tokenUris[0],
        category: uint24(100),
        allowManualMint: true, // Allow this type of mint
        shouldUseReservedTokenBeneficiaryAsDefault: false,
        transfersPausable: false,
        useVotingUnits: true
      });
      _tiersToMint[0] = 1;
      
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      vm.prank(owner);
      uint256 _tokenId = _generateTokenId(_tiersToMint[0], 1);
      _delegate.mintFor(_tiersToMint, _previousOwner);
      assertEq(_delegate.firstOwnerOf(_tokenId), _previousOwner);
      vm.prank(_previousOwner);
      IERC721(_delegate).transferFrom(_previousOwner, _owner, _tokenId);
      assertEq(_delegate.firstOwnerOf(_tokenId), _previousOwner);
    }
    function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnAddressZeroIfNotMinted(
      uint256 tokenId
    ) public {
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      assertEq(_delegate.firstOwnerOf(tokenId), address(0));
    }
    function testJBTieredNFTRewardDelegate_constructor_deployIfNoEmptyInitialQuantity(uint256 nbTiers)
      public
    {
      nbTiers = bound(nbTiers, 0, 10);
      // Create new tiers array
      JB721TierParams[] memory _tierParams = new JB721TierParams[](nbTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](nbTiers);
      for (uint256 i; i < nbTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104(i * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        new JBTiered721DelegateStore(),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Check: delegate has correct parameters?
      assertEq(_delegate.projectId(), projectId);
      assertEq(address(_delegate.directory()), mockJBDirectory);
      assertEq(_delegate.name(), name);
      assertEq(_delegate.symbol(), symbol);
      assertEq(
        address(_delegate.store().tokenUriResolverOf(address(_delegate))),
        mockTokenUriResolver
      );
      assertEq(_delegate.contractURI(), contractUri);
      assertEq(_delegate.owner(), owner);
      assertTrue(_isIn(_delegate.store().tiersOf(address(_delegate), new uint256[](0), 0, nbTiers), _tiers)); // Order is not insured
      assertTrue(_isIn(_tiers, _delegate.store().tiersOf(address(_delegate), new uint256[](0), 0, nbTiers)));
    }
    function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyInitialQuantity(
      uint256 nbTiers,
      uint256 errorIndex
    ) public {
      nbTiers = bound(nbTiers, 1, 20);
      errorIndex = bound(errorIndex, 0, nbTiers-1);
      // Create new tiers array
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104(i * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      _tiers[errorIndex].initialQuantity = 0;
      JBTiered721DelegateStore _dataSourceStore = new JBTiered721DelegateStore();
      // Expect the error at i+1 (as the floor is now smaller than i)
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.NO_QUANTITY.selector));
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({tiers: _tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
        _dataSourceStore,
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
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
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      // Temp tiers, will get overwritten later (pass the constructor check)
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < nbTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      for (uint256 tier = 1; tier <= nbTiers; tier++) {
        uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(
          address(_delegate),
          tier
        );
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
    function testJBTieredNFTRewardDelegate_mintReservesFor_mintMultipleReservedToken() public {
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
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      // Temp tiers, will get overwritten later (pass the constructor check)
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < nbTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      uint256 _totalMintable; // Keep a running counter
      JBTiered721MintReservesForTiersData[]
        memory _reservedToMint = new JBTiered721MintReservesForTiersData[](nbTiers);
      for (uint256 tier = 1; tier <= nbTiers; tier++) {
        uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(
          address(_delegate),
          tier
        );
        _reservedToMint[tier - 1] = JBTiered721MintReservesForTiersData({
          tierId: tier,
          count: mintable
        });
        _totalMintable += mintable;
        for (uint256 token = 1; token <= mintable; token++) {
          uint256 _tokenNonce = totalMinted + token; // Avoid stack too deep
          vm.expectEmit(true, true, true, true, address(_delegate));
          emit MintReservedToken(
            _generateTokenId(tier, _tokenNonce),
            tier,
            reserveBeneficiary,
            owner
          );
        }
      }
      vm.prank(owner);
      _delegate.mintReservesFor(_reservedToMint);
      // Check balance
      assertEq(_delegate.balanceOf(reserveBeneficiary), _totalMintable);
    }
    function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfReservedMintingIsPausedInFundingCycle()
      public
    {
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
      vm.mockCall(
        mockJBFundingCycleStore,
        abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
        abi.encode(
          JBFundingCycle({
            number: 1,
            configuration: block.timestamp,
            basedOn: 0,
            start: block.timestamp,
            duration: 600,
            weight: 10e18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0)),
            metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
              JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                  allowSetTerminals: false,
                  allowSetController: false,
                  pauseTransfers: false
                }),
                reservedRate: 5000, //50%
                redemptionRate: 5000, //50%
                ballotRedemptionRate: 5000,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(0),
                metadata: 2 // == 010_2
              })
            )
          })
        )
      );
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      // Temp tiers, will get overwritten later (pass the constructor check)
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < nbTiers; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      for (uint256 tier = 1; tier <= nbTiers; tier++) {
        uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(
          address(_delegate),
          tier
        );
        vm.prank(owner);
        vm.expectRevert(JBTiered721Delegate.RESERVED_TOKEN_MINTING_PAUSED.selector);
        _delegate.mintReservesFor(tier, mintable);
      }
    }
    function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfNotEnoughReservedLeft() public {
      uint256 initialQuantity = 200;
      uint256 totalMinted = 120;
      uint256 reservedMinted = 1;
      uint256 reservedRate = 4000;
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      for (uint256 i; i < 10; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      for (uint256 i = 1; i <= 10; i++) {
        // Get the amount that we can mint successfully
        uint256 amount = _delegate.test_store().numberOfReservedTokensOutstandingFor(
          address(_delegate),
          i
        );
        // Increase it by 1 to cause an error
        amount++;
        vm.expectRevert(
          abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector)
        );
        vm.prank(owner);
        _delegate.mintReservesFor(i, amount);
      }
    }
    function testJBTieredNFTRewardDelegate_use_default_reserved_token_beneficiary() public {
      uint256 initialQuantity = 200;
      uint256 totalMinted = 120;
      uint256 reservedRate = 9;
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      // Temp tiers, will get overwritten later
      for (uint256 i; i < 10; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(1),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: true,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
      }
    }
    function testJBTieredNFTRewardDelegate_no_reserved_rate_if_no_beneficiary_set() public {
      uint256 initialQuantity = 200;
      uint256 totalMinted = 120;
      uint256 reservedMinted = 10;
      uint256 reservedRate = 9;
      JB721TierParams[] memory _tiers = new JB721TierParams[](10);
      // Temp tiers, will get overwritten later
      for (uint256 i; i < 10; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(1),
          reservedTokenBeneficiary: address(0),
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      for (uint256 i; i < 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i + 1,
          JBStored721Tier({
            price: uint104((i + 1) * 10),
           remainingQuantity: uint32(initialQuantity - totalMinted),
            initialQuantity: uint32(initialQuantity),
            votingUnits: uint16(0),
            reservedRate: uint16(reservedRate),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: true
          })
        );
        _delegate.test_store().ForTest_setReservesMintedFor(
          address(_delegate),
          i + 1,
          reservedMinted
        );
      }
      // fetching existing tiers
      JB721Tier[] memory _storedTiers = _delegate.test_store().tiersOf(
          address(_delegate),
          new uint256[](0),
          0,
          10
      );
      // making sure reserved rate is 0
      for (uint256 i; i < 10; i++)
        assertEq(
          _storedTiers[i].reservedRate,
          0
        );
      for (uint256 i; i < 10; i++)
        assertEq(
          _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), i + 1),
          0
        );
    }
    function testJBTieredNFTRewardDelegate_mintFor_mintArrayOfTiers() public {
      uint256 nbTiers = 3;
      vm.mockCall(
        mockJBProjects,
        abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
        abi.encode(owner)
      );
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
      // Temp tiers, will get overwritten later (pass the constructor check)
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: true, // Allow this type of mint
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersToMint[i] = uint16(i)+1;
        _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i)+1;
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      vm.prank(owner);
      _delegate.mintFor(_tiersToMint, beneficiary);
      assertEq(_delegate.balanceOf(beneficiary), 6);
      assertEq(_delegate.ownerOf(_generateTokenId(1, 1)), beneficiary);
      assertEq(_delegate.ownerOf(_generateTokenId(1, 2)), beneficiary);
      assertEq(_delegate.ownerOf(_generateTokenId(2, 1)), beneficiary);
      assertEq(_delegate.ownerOf(_generateTokenId(2, 2)), beneficiary);
      assertEq(_delegate.ownerOf(_generateTokenId(3, 1)), beneficiary);
      assertEq(_delegate.ownerOf(_generateTokenId(3, 2)), beneficiary);
    }
    function testJBTieredNFTRewardDelegate_mintFor_revertIfManualMintNotAllowed() public {
      uint256 nbTiers = 3;
      vm.mockCall(
        mockJBProjects,
        abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
        abi.encode(owner)
      );
      JB721TierParams[] memory _tiers = new JB721TierParams[](nbTiers);
      uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
      // Temp tiers, will get overwritten later (pass the constructor check)
      for (uint256 i; i < nbTiers; i++) {
        _tiers[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[i],
          category: uint24(100),
          allowManualMint: true,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersToMint[i] = uint16(i)+1;
        _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i)+1;
      }
      _tiers[2].allowManualMint = false;
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      vm.prank(owner);
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.CANT_MINT_MANUALLY.selector));
      _delegate.mintFor(_tiersToMint, beneficiary);
    }
    function testJBTieredNFTRewardDelegate_tiers_adjustTier_remove_tiers_multiple_times(
      uint256 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      initialNumberOfTiers = bound(initialNumberOfTiers, 3, 14);
      vm.assume(floorTiersToAdd.length > 2 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending orderen
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JBTiered721Delegate _delegate;
      JB721Tier[] memory _tiers;
      {
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      }
      _delegate.transferOwnership(owner);
      {
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      // removing some tiers
      uint256[] memory tiersToRemove = new uint256[](2);
      tiersToRemove[0] = initialNumberOfTiers - 1;
      tiersToRemove[1] = initialNumberOfTiers - 2;
      vm.startPrank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, tiersToRemove);
      // clean tiers
      _delegate.store().cleanTiers(address(_delegate));
      vm.stopPrank();
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length
      );
      assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length - 2);
      tiersToRemove = new uint256[](2);
      tiersToRemove[0] = floorTiersToAdd.length - 1;
      tiersToRemove[1] = floorTiersToAdd.length - 2;
      vm.startPrank(owner);
      _delegate.adjustTiers(new JB721TierParams[](0), tiersToRemove);
      // clean tiers again
      _delegate.store().cleanTiers(address(_delegate));
      vm.stopPrank();
      _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length - 4
      );
      assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length - 4);
      // if the tiers have same category then the the tiers added last will have a lower index in the array
      // else the tiers would be sorted by categories
      for (uint256 i = 1; i < _storedTiers.length; i++) {
        if (_storedTiers[i - 1].category == _storedTiers[i].category)
          assertGt(_storedTiers[i - 1].id, _storedTiers[i].id);
        else assertLt(_storedTiers[i - 1].category, _storedTiers[i].category);
      }
      }
    }
    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise_after_tiers_have_been_cleaned(
      uint256 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      initialNumberOfTiers = bound(initialNumberOfTiers, 3, 14);
      vm.assume(floorTiersToAdd.length > 1 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending orderen
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JBTiered721Delegate _delegate;
      JB721Tier[] memory _tiers;
      {
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      }
      _delegate.transferOwnership(owner);
      {
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.startPrank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      // clean tiers
      _delegate.store().cleanTiers(address(_delegate));
      vm.stopPrank();
      // add again
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
      }
      uint256[] memory tiersToRemove = new uint256[](2);
      tiersToRemove[0] = initialNumberOfTiers - 1;
      tiersToRemove[1] = initialNumberOfTiers - 2;
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, tiersToRemove);
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length * 2 - 2
      );
      assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2 - 2);
      // if the tiers have same category then the the tiers added last will have a lower index in the array
      // else the tiers would be sorted by categories
      for (uint256 i = 1; i < _storedTiers.length; i++) {
        if (_storedTiers[i - 1].category == _storedTiers[i].category)
          assertGt(_storedTiers[i - 1].id, _storedTiers[i].id);
        else assertLt(_storedTiers[i - 1].category, _storedTiers[i].category);
      }
      }
    }
    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15 && initialNumberOfTiers > 0);
      vm.assume(floorTiersToAdd.length > 1 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length
      );
      // if the tiers have same category then the the tiers added last will have a lower index in the array
      // else the tiers would be sorted by categories
      for (uint256 i = 1; i < _storedTiers.length; i++) {
        if (_storedTiers[i - 1].category == _storedTiers[i].category)
          assertGt(_storedTiers[i - 1].id, _storedTiers[i].id);
        else assertLt(_storedTiers[i - 1].category, _storedTiers[i].category);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers_With_Non_Sequential_Categories(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15 && initialNumberOfTiers > 0);
      vm.assume(floorTiersToAdd.length > 1 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 1),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(i * 2 + 2),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length
      );
      // Check: Expected number of tiers?
      assertEq(_storedTiers.length, _tiers.length + _tiersAdded.length);
      // Check: Are all tiers in the new tiers (unsorted)?
      assertTrue(_isIn(_tiers, _storedTiers)); // Original tiers
      assertTrue(_isIn(_tiersAdded, _storedTiers)); // New tiers
      // Check: Are all the tiers sorted?
      for (uint256 i = 1; i < _storedTiers.length; i++) {
        assertLt(_storedTiers[i - 1].category, _storedTiers[i].category);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length
      );
      // Check: Expected number of tiers?
      assertEq(_storedTiers.length, _tiers.length + _tiersAdded.length);
      // Check: Are all tiers in the new tiers (unsorted)?
      assertTrue(_isIn(_tiers, _storedTiers)); // Original tiers
      assertTrue(_isIn(_tiersAdded, _storedTiers)); // New tiers
      // Check: Are all the tiers sorted?
      for (uint256 i = 1; i < _storedTiers.length; i++) {
        assertLe(_storedTiers[i - 1].category, _storedTiers[i].category);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_with_same_category_multiple_times(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(101),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      // add again with category 101
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(11),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(101),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + floorTiersToAdd.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      {
        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
          address(_delegate),
          new uint256[](0),
          0,
          initialNumberOfTiers + floorTiersToAdd.length * 2
        );
        assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2);
      }
      uint256[] memory _categories =  new uint256[](1);
      _categories[0] = 101;
      JB721Tier[] memory _stored101Tiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        floorTiersToAdd.length * 2
      );
      assertEq(_stored101Tiers.length, floorTiersToAdd.length * 2);
      _categories[0] = 100;
      JB721Tier[] memory _stored100Tiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        initialNumberOfTiers
      );
      assertEq(_stored100Tiers.length, initialNumberOfTiers);
      // Ensure order
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        assertGt(_stored101Tiers[i].id, _stored101Tiers[i + floorTiersToAdd.length].id);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_with_different_categories(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(101),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      // add a new category
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(11),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(102),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + floorTiersToAdd.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      JB721Tier[] memory _allStoredTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        initialNumberOfTiers + floorTiersToAdd.length * 2
      );
      uint256[] memory _categories =  new uint256[](1);
      _categories[0] = 102;
      JB721Tier[] memory _stored102Tiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        floorTiersToAdd.length
      );
      assertEq(_stored102Tiers.length, floorTiersToAdd.length);
      for (uint256 i = 0; i < _stored102Tiers.length; i++) {
        assertEq(_stored102Tiers[i].category, uint8(102));
      }
      _categories[0] = 101;
      JB721Tier[] memory _stored101Tiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        floorTiersToAdd.length
      );
      assertEq(_stored101Tiers.length, floorTiersToAdd.length);
      for (uint256 i = 0; i < _stored101Tiers.length; i++) {
        assertEq(_stored101Tiers[i].category, uint8(101));
      }
      for (uint256 i = 1; i < initialNumberOfTiers + floorTiersToAdd.length * 2; i++) {
        assertGt(_allStoredTiers[i].id, _allStoredTiers[i - 1].id);
        assertLe(_allStoredTiers[i - 1].category, _allStoredTiers[i].category);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_with_0_category(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 40);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(0),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(5),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      uint256[] memory _categories =  new uint256[](1);
      _categories[0] = 0;
      JB721Tier[] memory _allStoredTiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        initialNumberOfTiers
      );
      assertEq(_allStoredTiers.length,  initialNumberOfTiers);
      for (uint256 i = 0; i <  _allStoredTiers.length; i++) {
        assertEq(_allStoredTiers[i].category, uint8(0));
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_with_different_categories_and_fetched_together(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(101),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      // add a new category
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(11),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(102),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + floorTiersToAdd.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      uint256[] memory _categories =  new uint256[](3);
      _categories[0] = 102;
      _categories[1] = 100;
      _categories[2] = 101;
      JB721Tier[] memory _allStoredTiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        initialNumberOfTiers + floorTiersToAdd.length * 2
      );
      assertEq(_allStoredTiers.length,  initialNumberOfTiers + floorTiersToAdd.length * 2);
      uint tier_100_max_index = _allStoredTiers.length - floorTiersToAdd.length;
      for (uint256 i = 0; i <  floorTiersToAdd.length; i++) {
        assertEq(_allStoredTiers[i].category, uint8(102));
      }
      for (uint256 i = floorTiersToAdd.length; i < tier_100_max_index; i++) {
        assertEq(_allStoredTiers[i].category, uint8(100));
      }
      for (uint256 i = tier_100_max_index; i < _allStoredTiers.length; i++) {
        assertEq(_allStoredTiers[i].category, uint8(101));
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers_fetch_specifc_tier(
      uint16 initialNumberOfTiers,
      uint16[] memory floorTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 15);
      vm.assume(floorTiersToAdd.length > 0 && floorTiersToAdd.length < 15);
      // Floor are sorted in ascending order
      floorTiersToAdd = _sortArray(floorTiersToAdd);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: false,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](floorTiersToAdd.length);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](floorTiersToAdd.length);
      for (uint256 i; i < floorTiersToAdd.length; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 10,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(101),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
      uint256[] memory _categories =  new uint256[](1);
      _categories[0] = 101;
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        _categories,
        0,
        initialNumberOfTiers + floorTiersToAdd.length
      );
      // check no of tiers
      assertEq(_storedTiers.length, floorTiersToAdd.length);
      // Check: Are all the tiers sorted?
      for (uint256 i = 0; i < _storedTiers.length; i++) {
        assertEq(_storedTiers[i].category, uint8(101));
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_removeTiers(
      uint16 initialNumberOfTiers,
      uint256 seed,
      uint8 numberOfTiersToRemove
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 15);
      vm.assume(numberOfTiersToRemove > 0 && numberOfTiersToRemove < initialNumberOfTiers);
      // Create random tiers to remove
      uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);
      // seed to generate new random tiers, i to iterate to fill the tiersToRemove array
      for (uint256 i; i < numberOfTiersToRemove; ) {
        uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
        bool _invalidTier;
        if (_newTierCandidate != 0) {
          for (uint256 j; j < numberOfTiersToRemove; j++)
            // Same value twice?
            if (_newTierCandidate == tiersToRemove[j]) {
              _invalidTier = true;
              break;
            }
          if (!_invalidTier) {
            tiersToRemove[i] = _newTierCandidate;
            i++;
          }
        }
        // Overflow to loop over (seed is fuzzed, can be starting at max(uint256))
        unchecked {
          seed++;
        }
      }
      // Order the tiers to remove for event matching (which are ordered too)
      tiersToRemove = _sortArray(tiersToRemove);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Will be resized later
      JB721TierParams[] memory tierParamsRemaining = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < _tiers.length; i++) {
        tierParamsRemaining[i] = _tierParams[i];
        tiersRemaining[i] = _tiers[i];
      }
      for (uint256 i; i < tiersRemaining.length; ) {
        bool _swappedAndPopped;
        for (uint256 j; j < tiersToRemove.length; j++)
          if (tiersRemaining[i].id == tiersToRemove[j]) {
            // Swap and pop tiers removed
            tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
            tierParamsRemaining[i] = tierParamsRemaining[tierParamsRemaining.length - 1];
            // Remove the last elelment / reduce array length by 1
            assembly ("memory-safe") {
              mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
              mstore(tierParamsRemaining, sub(mload(tierParamsRemaining), 1))
            }
            _swappedAndPopped = true;
            break;
          }
        if (!_swappedAndPopped) i++;
      }
      // Check: correct event params?
      for (uint256 i; i < tiersToRemove.length; i++) {
        vm.expectEmit(true, false, false, true, address(_delegate));
        emit RemoveTier(tiersToRemove[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(new JB721TierParams[](0), tiersToRemove);
      {
        uint256 finalNumberOfTiers = initialNumberOfTiers - tiersToRemove.length;
        JB721Tier[] memory _storedTiers = _delegate.test_store().tiersOf(
          address(_delegate),
          new uint256[](0),
          0,
          finalNumberOfTiers
        );
        // Check expected number of tiers remainings
        assertEq(_storedTiers.length, finalNumberOfTiers);
        // Check that all the remaining tiers still exist
        assertTrue(_isIn(tiersRemaining, _storedTiers));
        // Check that none of the removed tiers still exist
        assertTrue(_isIn(_storedTiers, tiersRemaining));
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_addAndRemoveTiers() public {
      uint256 initialNumberOfTiers = 5;
      uint256 numberOfTiersToAdd = 5;
      uint256 numberOfTiersToRemove = 3;
      uint256[] memory floorTiersToAdd = new uint256[](numberOfTiersToAdd);
      floorTiersToAdd[0] = 1;
      floorTiersToAdd[1] = 4;
      floorTiersToAdd[2] = 5;
      floorTiersToAdd[3] = 6;
      floorTiersToAdd[4] = 10;
      uint256[] memory tierIdToRemove = new uint256[](numberOfTiersToRemove);
      tierIdToRemove[0] = 1;
      tierIdToRemove[1] = 3;
      tierIdToRemove[2] = 4;
      // Initial tiers data
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      //  Deploy the delegate with the initial tiers
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // -- Build expected removed/remaining tiers --
      JB721TierParams[] memory _tierDataRemaining = new JB721TierParams[](2);
      JB721Tier[] memory _tiersRemaining = new JB721Tier[](2);
      uint256 _arrayIndex;
      for (uint256 i; i < initialNumberOfTiers; i++) {
        // Tiers which will remain
        if (i + 1 != 1 && i + 1 != 3 && i + 1 != 4) {
          _tierDataRemaining[_arrayIndex] = JB721TierParams({
            price: uint104((i + 1) * 10),
            initialQuantity: uint32(100),
            votingUnits: uint16(0),
            reservedRate: uint16(i),
            reservedTokenBeneficiary: reserveBeneficiary,
            encodedIPFSUri: tokenUris[0],
            category: uint24(100),
            allowManualMint: false,
            shouldUseReservedTokenBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: true
          });
          _tiersRemaining[_arrayIndex] = JB721Tier({
            id: i + 1,
            price: _tierDataRemaining[_arrayIndex].price,
            remainingQuantity: _tierDataRemaining[_arrayIndex].initialQuantity,
            initialQuantity: _tierDataRemaining[_arrayIndex].initialQuantity,
            votingUnits: _tierDataRemaining[_arrayIndex].votingUnits,
            reservedRate: _tierDataRemaining[_arrayIndex].reservedRate,
            reservedTokenBeneficiary: _tierDataRemaining[_arrayIndex].reservedTokenBeneficiary,
            encodedIPFSUri: _tierDataRemaining[_arrayIndex].encodedIPFSUri,
            category: _tierDataRemaining[_arrayIndex].category,
            allowManualMint: _tierDataRemaining[_arrayIndex].allowManualMint,
            transfersPausable: _tierDataRemaining[_arrayIndex].transfersPausable,
            resolvedUri: ""
          });
          _arrayIndex++;
        } else {
          // Otherwise, part of the tiers removed:
          // Check: correct event params?
          vm.expectEmit(true, false, false, true, address(_delegate));
          emit RemoveTier(i + 1, owner);
        }
      }
      // -- Build expected added tiers --
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](numberOfTiersToAdd);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](numberOfTiersToAdd);
      for (uint256 i; i < numberOfTiersToAdd; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104(floorTiersToAdd[i]) * 11,
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100 + i),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
        vm.expectEmit(true, true, true, true, address(_delegate));
        emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
      }
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, tierIdToRemove);
      JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
        address(_delegate),
        new uint256[](0),
        0,
        7 // 7 tiers remaining - Hardcoded to avoid stack too deep
      );
      // Check: Expected number of remaining tiers?
      assertEq(_storedTiers.length, 7);
      // // Check: Are all non-deleted and added tiers in the new tiers (unsorted)?
      assertTrue(_isIn(_tiersRemaining, _storedTiers)); // Original tiers
      assertTrue(_isIn(_tiersAdded, _storedTiers)); // New tiers
      // Check: Are all the deleted tiers removed (remaining is tested supra)?
      assertFalse(_isIn(_tiers, _storedTiers)); // Will emit _isIn: incomplete inclusion but without failing assertion
      // Check: Are all the tiers sorted?
      for (uint256 j = 1; j < _storedTiers.length; j++) {
        assertLe(_storedTiers[j - 1].category, _storedTiers[j].category);
      }
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithVotingPower(
      uint8 initialNumberOfTiers,
      uint8 numberTiersToAdd
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 30);
      vm.assume(numberTiersToAdd > 0);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](numberTiersToAdd);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
      for (uint256 i; i < numberTiersToAdd; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104((i + 1) * 100),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
      }
      vm.expectRevert(
        abi.encodeWithSelector(JBTiered721DelegateStore.VOTING_UNITS_NOT_ALLOWED.selector)
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
      JB721TierParams[] memory _tierParam = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParam[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParam[i].price,
          remainingQuantity: _tierParam[i].initialQuantity,
          initialQuantity: _tierParam[i].initialQuantity,
          votingUnits: _tierParam[i].votingUnits,
          reservedRate: _tierParam[i].reservedRate,
          reservedTokenBeneficiary: _tierParam[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParam[i].encodedIPFSUri,
          category: _tierParam[i].category,
          allowManualMint: _tierParam[i].allowManualMint,
          transfersPausable: _tierParam[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParam,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](numberTiersToAdd);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
      for (uint256 i; i < numberTiersToAdd; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104((i + 1) * 100),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i + 1),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
      }
      vm.expectRevert(
        abi.encodeWithSelector(JBTiered721DelegateStore.RESERVED_RATE_NOT_ALLOWED.selector)
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
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: true
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](numberTiersToAdd);
      JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
      for (uint256 i; i < numberTiersToAdd; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104((i + 1) * 100),
          initialQuantity: uint32(0),
          votingUnits: uint16(0),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiersAdded[i] = JB721Tier({
          id: _tiers.length + (i + 1),
          price: _tierParamsToAdd[i].price,
          remainingQuantity: _tierParamsToAdd[i].initialQuantity,
          initialQuantity: _tierParamsToAdd[i].initialQuantity,
          votingUnits: _tierParamsToAdd[i].votingUnits,
          reservedRate: _tierParamsToAdd[i].reservedRate,
          reservedTokenBeneficiary: _tierParamsToAdd[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
          category: _tierParamsToAdd[i].category,
          allowManualMint: _tierParamsToAdd[i].allowManualMint,
          transfersPausable: _tierParamsToAdd[i].transfersPausable,
          resolvedUri: ""
        });
      }
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.NO_QUANTITY.selector));
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfRemovingALockedTier(
      uint16 initialNumberOfTiers,
      uint8 tierLockedIndex
    ) public {
      vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 15);
      vm.assume(tierLockedIndex < initialNumberOfTiers - 1);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({
          tiers: _tierParams,
          currency: 1,
          decimals: 18,
          prices: IJBPrices(address(0))
        }),
        IJBTiered721DelegateStore(address(_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      uint256[] memory _tierToRemove = new uint256[](1);
      _tierToRemove[0] = tierLockedIndex + 1;
      // Check: reomve tier after lock
      vm.warp(block.timestamp + 11);
      vm.prank(owner);
      _delegate.adjustTiers(new JB721TierParams[](0), _tierToRemove);
      // Check: one less tier
      assertEq(
        _delegate.store().tiersOf(address(_delegate), new uint256[](0), 0, initialNumberOfTiers).length,
        initialNumberOfTiers - 1
      );
    }
    function testJBTieredNFTRewardDelegate_cleanTiers_removeTheInactiveTiers(
      uint16 initialNumberOfTiers,
      uint256 seed,
      uint8 numberOfTiersToRemove
    ) public {
      // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers > 0 && initialNumberOfTiers < 15);
      vm.assume(numberOfTiersToRemove > 0 && numberOfTiersToRemove < initialNumberOfTiers);
      // Create random tiers to remove
      uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);
      // seed to generate new random tiers, i to iterate to fill the tiersToRemove array
      for (uint256 i; i < numberOfTiersToRemove; ) {
        uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
        bool _invalidTier;
        if (_newTierCandidate != 0) {
          for (uint256 j; j < numberOfTiersToRemove; j++)
            // Same value twice?
            if (_newTierCandidate == tiersToRemove[j]) {
              _invalidTier = true;
              break;
            }
          if (!_invalidTier) {
            tiersToRemove[i] = _newTierCandidate;
            i++;
          }
        }
        // Overflow to loop over (seed is fuzzed, can be starting at max(uint256))
        unchecked {
          seed++;
        }
      }
      // Order the tiers to remove for event matching (which are ordered too)
      tiersToRemove = _sortArray(tiersToRemove);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
        _tiers[i] = JB721Tier({
          id: i + 1,
          price: _tierParams[i].price,
          remainingQuantity: _tierParams[i].initialQuantity,
          initialQuantity: _tierParams[i].initialQuantity,
          votingUnits: _tierParams[i].votingUnits,
          reservedRate: _tierParams[i].reservedRate,
          reservedTokenBeneficiary: _tierParams[i].reservedTokenBeneficiary,
          encodedIPFSUri: _tierParams[i].encodedIPFSUri,
          category: _tierParams[i].category,
          allowManualMint: _tierParams[i].allowManualMint,
          transfersPausable: _tierParams[i].transfersPausable,
          resolvedUri: ""
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Will be resized later
      JB721TierParams[] memory tierParamsRemaining = new JB721TierParams[](initialNumberOfTiers);
      JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
      for (uint256 i; i < _tiers.length; i++) {
        tierParamsRemaining[i] = _tierParams[i];
        tiersRemaining[i] = _tiers[i];
      }
      for (uint256 i; i < tiersRemaining.length; ) {
        bool _swappedAndPopped;
        for (uint256 j; j < tiersToRemove.length; j++)
          if (tiersRemaining[i].id == tiersToRemove[j]) {
            // Swap and pop tiers removed
            tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
            tierParamsRemaining[i] = tierParamsRemaining[tierParamsRemaining.length - 1];
            // Remove the last elelment / reduce array length by 1
            assembly ("memory-safe") {
              mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
              mstore(tierParamsRemaining, sub(mload(tierParamsRemaining), 1))
            }
            _swappedAndPopped = true;
            break;
          }
        if (!_swappedAndPopped) i++;
      }
      vm.prank(owner);
      _delegate.adjustTiers(new JB721TierParams[](0), tiersToRemove);
      JB721Tier[] memory _tiersListDump = _delegate.test_store().ForTest_dumpTiersList(
        address(_delegate)
      );
      // Check: all the tiers are still in the linked list (both active and inactives)
      assertTrue(_isIn(_tiers, _tiersListDump));
      // Check: the linked list include only the tiers (active and inactives)
      assertTrue(_isIn(_tiersListDump, _tiers));
      // Check: correct event
      vm.expectEmit(true, false, false, true, address(_delegate.test_store()));
      emit CleanTiers(address(_delegate), beneficiary);
      vm.startPrank(beneficiary);
      _delegate.test_store().cleanTiers(address(_delegate));
      vm.stopPrank();
      _tiersListDump = _delegate.test_store().ForTest_dumpTiersList(address(_delegate));
      // check no of tiers
      assertEq(_tiersListDump.length, initialNumberOfTiers - numberOfTiersToRemove);
      // Check: the activer tiers are in the likned list
      assertTrue(_isIn(tiersRemaining, _tiersListDump));
      // Check: the linked list is only the active tiers
      assertTrue(_isIn(_tiersListDump, tiersRemaining));
    }
    // ----------------
    //        Pay
    // ----------------
    // If the amount payed is below the price to receive an NFT the pay should not revert if no metadata passed
    function testJBTieredNFTRewardDelegate_didPay_doesNotOnAmountBelowPriceIfNoMetadata()
      public
    {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, tiers[0].price - 1, 18, JBCurrencies.ETH), // 1 wei below the minimum amount
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          new bytes(0)
        )
      );
      assertEq(delegate.creditsOf(msg.sender), tiers[0].price - 1);
    }
    // If the amount is above contribution floor and a tier is passed, mint as many corresponding tier as possible
    function testJBTieredNFTRewardDelegate_didPay_mintCorrectTier() public {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
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
            tiers[0].price * 2 + tiers[1].price,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure a new NFT was minted
      assertEq(_totalSupplyBeforePay + 3, delegate.store().totalSupply(address(delegate)));
      // Correct tier has been minted?
      assertEq(delegate.ownerOf(_generateTokenId(1, 1)), msg.sender);
      assertEq(delegate.ownerOf(_generateTokenId(1, 2)), msg.sender);
      assertEq(delegate.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }
    function testJBTieredNFTRewardDelegate_didPay_mintNoneIfNonePassed(uint8 _amount) public {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](0);
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure no new NFT was minted if amount >= contribution floor
      assertEq(_totalSupplyBeforePay, delegate.store().totalSupply(address(delegate)));
    }
    function testJBTieredNFTRewardDelegate_didPay_mintTierAndTrackLeftover() public {
      uint256 _leftover = tiers[0].price - 1;
      uint256 _amount = tiers[0].price + _leftover;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](1);
      _tierIdsToMint[0] = uint16(1);
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      // calculating new credits
      uint256 _newCredits = _leftover + delegate.creditsOf(beneficiary);
      vm.expectEmit(true, true, true, true, address(delegate));
      emit AddCredits(
            _newCredits,
            _newCredits,
            beneficiary,
            mockTerminalAddress
      );
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      // Check: credit is updated?
      assertEq(delegate.creditsOf(beneficiary), _leftover);
    }
    // Mint a given tier with a leftover, mint another given tier then, if the accumulated credit is enough, mint an extra tier
    function testJBTieredNFTRewardDelegate_didPay_mintCorrectTiersWhenUsingPartialCredits() public {
      uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
      uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      uint256 _credits = delegate.creditsOf(beneficiary);
      _leftover = _leftover / 2 + _credits; //left over amount
      vm.expectEmit(true, true, true, true, address(delegate));
      emit AddCredits(
            _leftover - _credits,
            _leftover,
            beneficiary,
            mockTerminalAddress
      );
      // First call will mint the 3 tiers requested + accumulate half of first floor in credit
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          beneficiary,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      uint256 _totalSupplyBefore = delegate.store().totalSupply(address(delegate));
      {
        // We now attempt an additional tier 1 by using the credit we collected from last pay
        uint16[] memory _moreTierIdsToMint = new uint16[](4);
        _moreTierIdsToMint[0] = 1;
        _moreTierIdsToMint[1] = 1;
        _moreTierIdsToMint[2] = 2;
        _moreTierIdsToMint[3] = 1;
        _metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
          _allowOverspending,
          _moreTierIdsToMint
        );
      }
     // fetch existing credits
      _credits = delegate.creditsOf(beneficiary);
      vm.expectEmit(true, true, true, true, address(delegate));
      emit UseCredits(
            _credits,
            0, // no stashed credits
            beneficiary,
            mockTerminalAddress
      );
      // Second call will mint another 3 tiers requested + mint from the first tier with the credit
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          beneficiary,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      // Check: total supply has increased?
      assertEq(_totalSupplyBefore + 4, delegate.store().totalSupply(address(delegate)));
      // Check: correct tiers have been minted
      // .. On first pay?
      assertEq(delegate.ownerOf(_generateTokenId(1, 1)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(1, 2)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(2, 1)), beneficiary);
      // ... On second pay?
      assertEq(delegate.ownerOf(_generateTokenId(1, 3)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(1, 4)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(1, 5)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(2, 2)), beneficiary);
      // Check: no credit is left?
      assertEq(delegate.creditsOf(beneficiary), 0);
    }
    function testJBTieredNFTRewardDelegate_didPay_doNotMintWithSomeoneElseCredit() public {
      uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
      uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      // First call will mint the 3 tiers requested + accumulate half of first floor in credit
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          beneficiary,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      uint256 _totalSupplyBefore = delegate.store().totalSupply(address(delegate));
      uint256 _creditBefore = delegate.creditsOf(beneficiary);
      // Second call will mint another 3 tiers requested BUT not with the credit accumulated
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      // Check: total supply has increased with the 3 token?
      assertEq(_totalSupplyBefore + 3, delegate.store().totalSupply(address(delegate)));
      // Check: correct tiers have been minted
      // .. On first pay?
      assertEq(delegate.ownerOf(_generateTokenId(1, 1)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(1, 2)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(2, 1)), beneficiary);
      // ... On second pay, without extra from the credit?
      assertEq(delegate.ownerOf(_generateTokenId(1, 3)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(1, 4)), beneficiary);
      assertEq(delegate.ownerOf(_generateTokenId(2, 2)), beneficiary);
      // Check: credit is now having both left-overs?
      assertEq(delegate.creditsOf(beneficiary), _creditBefore * 2);
    }
    // Terminal is in currency 1 with 18 decimal, delegate is in currency 2, with 9 decimals
    // The conversion rate is set at 1:2
    function testJBTieredNFTRewardDelegate_didPay_mintCorrectTierWithAnotherCurrency() public {
      address _jbPrice = address(bytes20(keccak256('MockJBPrice')));
      vm.etch(_jbPrice, new bytes(1));
      vm.etch(delegate_i, address(delegate).code);
      JBTiered721Delegate _delegate = JBTiered721Delegate(delegate_i);
      _delegate.initialize(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        JB721PricingParams({tiers: tiers, currency: 2, decimals: 9, prices: IJBPrices(_jbPrice)}),
        new JBTiered721DelegateStore(),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: true,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      // Mock the price oracle call
      uint256 _amountInEth = (tiers[0].price * 2 + tiers[1].price) * 2;
      vm.mockCall(_jbPrice, abi.encodeCall(IJBPrices.priceFor, (1, 2, 18)), abi.encode(2 * 10**9));
      uint256 _totalSupplyBeforePay = _delegate.store().totalSupply(address(delegate));
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.prank(mockTerminalAddress);
      _delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amountInEth, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure a new NFT was minted
      assertEq(_totalSupplyBeforePay + 3, _delegate.store().totalSupply(address(_delegate)));
      // Correct tier has been minted?
      assertEq(_delegate.ownerOf(_generateTokenId(1, 1)), msg.sender);
      assertEq(_delegate.ownerOf(_generateTokenId(1, 2)), msg.sender);
      assertEq(_delegate.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }
    // If the tier has been removed, revert
    function testJBTieredNFTRewardDelegate_didPay_revertIfTierRemoved() public {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      uint256[] memory _toRemove = new uint256[](1);
      _toRemove[0] = 1;
      vm.prank(owner);
      delegate.adjustTiers(new JB721TierParams[](0), _toRemove);
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.TIER_REMOVED.selector));
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(
            JBTokens.ETH,
            tiers[0].price * 2 + tiers[1].price,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure no new NFT was minted
      assertEq(_totalSupplyBeforePay, delegate.store().totalSupply(address(delegate)));
    }
    function testJBTieredNFTRewardDelegate_didPay_revertIfNonExistingTier(uint16 _invalidTier)
      public
    {
      vm.assume(_invalidTier > tiers.length);
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](1);
      _tierIdsToMint[0] = _invalidTier;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      uint256[] memory _toRemove = new uint256[](1);
      _toRemove[0] = 1;
      vm.prank(owner);
      delegate.adjustTiers(new JB721TierParams[](0), _toRemove);
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INVALID_TIER.selector));
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(
            JBTokens.ETH,
            tiers[0].price * 2 + tiers[1].price,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure no new NFT was minted
      assertEq(_totalSupplyBeforePay, delegate.store().totalSupply(address(delegate)));
    }
    // If the amount is not enought to cover all the tiers requested, revert
    function testJBTieredNFTRewardDelegate_didPay_revertIfAmountTooLow() public {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_AMOUNT.selector));
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(
            JBTokens.ETH,
            tiers[0].price * 2 + tiers[1].price - 1,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      // Make sure no new NFT was minted
      assertEq(_totalSupplyBeforePay, delegate.store().totalSupply(address(delegate)));
    }
    function testJBTieredNFTRewardDelegate_didPay_revertIfAllowanceRunsOutInParticularTier() public {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256 _supplyLeft = tiers[0].initialQuantity;
      while (true) {
        uint256 _totalSupplyBeforePay = delegate.store().totalSupply(address(delegate));
        // If there is no supply left this should revert
        if (_supplyLeft == 0) {
          vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.OUT.selector));
        }
        bool _allowOverspending = true;
        uint16[] memory tierSelected = new uint16[](1);
        tierSelected[0] = 1;
        bytes memory _metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
          _allowOverspending,
          tierSelected
        );
        // Perform the pay
        vm.prank(mockTerminalAddress);
        delegate.didPay(
          JBDidPayData(
            msg.sender,
            projectId,
            0,
            JBTokenAmount(JBTokens.ETH, tiers[0].price, 18, JBCurrencies.ETH),
            JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
            0,
            msg.sender,
            false,
            '',
            _metadata
          )
        );
        // Make sure if there was no supply left there was no NFT minted
        if (_supplyLeft == 0) {
          assertEq(delegate.store().totalSupply(address(delegate)), _totalSupplyBeforePay);
          break;
        } else {
          assertEq(delegate.store().totalSupply(address(delegate)), _totalSupplyBeforePay + 1);
        }
        --_supplyLeft;
      }
    }
    function testJBTieredNFTRewardDelegate_didPay_revertIfCallerIsNotATerminalOfProjectId(
      address _terminal
    ) public {
      vm.assume(_terminal != mockTerminalAddress);
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
        abi.encode(false)
      );
      // The caller is the _expectedCaller however the terminal in the calldata is not correct
      vm.prank(_terminal);
      vm.expectRevert(abi.encodeWithSelector(JB721Delegate.INVALID_PAYMENT_EVENT.selector));
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(address(0), 0, 18, JBCurrencies.ETH),
          JBTokenAmount(address(0), 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          new bytes(0)
        )
      );
    }
    function testJBTieredNFTRewardDelegate_didPay_doNotMintIfNotUsingCorrectToken(address token)
      public
    {
      vm.assume(token != JBTokens.ETH);
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
          JBTokenAmount(token, 0, 18, JBCurrencies.ETH),
          JBTokenAmount(token, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          new bytes(0)
        )
      );
      // Check: nothing has been minted
      assertEq(delegate.store().totalSupply(address(delegate)), 0);
    }
    function testJBTieredNFTRewardDelegate_didPay_mintTiersWhenUsingExistingCredits_when_existing_credits_more_than_new_credits() public {
      uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
      uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      uint256 _credits = delegate.creditsOf(beneficiary);
      _leftover = _leftover / 2 + _credits; //left over amount
      vm.expectEmit(true, true, true, true, address(delegate));
      emit AddCredits(
            _leftover - _credits,
            _leftover,
            beneficiary,
            mockTerminalAddress
      );
      // First call will mint the 3 tiers requested + accumulate half of first floor in credit
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          beneficiary,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      uint256 _totalSupplyBefore = delegate.store().totalSupply(address(delegate));
      {
        // We now attempt an additional tier 1 by using the credit we collected from last pay
        uint16[] memory _moreTierIdsToMint = new uint16[](1);
        _moreTierIdsToMint[0] = 1;
        _metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
          _allowOverspending,
          _moreTierIdsToMint
        );
      }
      // fetch existing credits
      _credits = delegate.creditsOf(beneficiary);
      // using existing credits to mint
      _leftover = tiers[0].price - 1 - _credits;
      vm.expectEmit(true, true, true, true, address(delegate));
      emit UseCredits(
            _credits - _leftover,
            _leftover,
            beneficiary,
            mockTerminalAddress
      );
       // minting with left over credits
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          beneficiary,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, tiers[0].price - 1, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
      // total supply increases
      assertEq(_totalSupplyBefore + 1, delegate.store().totalSupply(address(delegate)));
    }
    function testJBTieredNFTRewardDelegate_didPay_revertIfUnexpectedLeftover() public {
      uint256 _leftover = tiers[1].price - 1;
      uint256 _amount = tiers[0].price + _leftover;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](0);
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.prank(mockTerminalAddress);
      vm.expectRevert(abi.encodeWithSelector(JBTiered721Delegate.OVERSPENDING.selector));
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
    }
     function testJBTieredNFTRewardDelegate_didPay_revertIfUnexpectedLeftoverAndPrevented(bool _prevent) public {
      uint256 _leftover = tiers[1].price - 1;
      uint256 _amount = tiers[0].price + _leftover;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      // Get the currently selected flags
      JBTiered721Flags memory flags = delegate.store().flagsOf(address(delegate));
      // Modify the prevent
      flags.preventOverspending = _prevent;
      // Mock the call to return the new flags
      vm.mockCall(
        address(delegate.store()),
        abi.encodeWithSelector(IJBTiered721DelegateStore.flagsOf.selector, address(delegate)),
        abi.encode(flags)
      );
      bool _allowOverspending = true;
      uint16[] memory _tierIdsToMint = new uint16[](0);
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      // If prevent is enabled the call should revert, otherwise we should receive credits
      if(_prevent){
        vm.expectRevert(abi.encodeWithSelector(JBTiered721Delegate.OVERSPENDING.selector));
      } else {
        uint256 _credits = delegate.creditsOf(beneficiary);
        uint256 _stashedCredits = _credits;
        // calculating new credits since _leftover is non zero
        uint256 _newCredits = tiers[0].price + _leftover + _stashedCredits;
        vm.expectEmit(true, true, true, true, address(delegate));
        emit AddCredits(
            _newCredits - _credits,
            _newCredits,
            beneficiary,
            mockTerminalAddress
        );
      }
      vm.prank(mockTerminalAddress);
      delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          beneficiary,
          false,
          '',
          _metadata
        )
      );
    }
    // Mint are still possible, transfer to other addresses than 0 (ie burn) are reverting (if delegate flag pausable is true)
    function testJBTieredNFTRewardDelegate_beforeTransferHook_revertTransferIfTransferPausedInFundingCycle()
      public
    {
      JB721TierParams[] memory _tierParams = new JB721TierParams[](5);
      // 5 tiers, floors from 10 to 50
      for (uint256 i; i < 5; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          reservedRate: uint16(0),
          encodedIPFSUri: tokenUris[0],
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          category: uint24(100),
          transfersPausable: true,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      vm.mockCall(
        mockJBFundingCycleStore,
        abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
        abi.encode(
          JBFundingCycle({
            number: 1,
            configuration: block.timestamp,
            basedOn: 0,
            start: block.timestamp,
            duration: 600,
            weight: 10e18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0)),
            metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
              JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                  allowSetTerminals: false,
                  allowSetController: false,
                  pauseTransfers: false
                }),
                reservedRate: 5000, //50%
                redemptionRate: 5000, //50%
                ballotRedemptionRate: 5000,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(_delegate),
                metadata: 1 // 001_2
              })
            )
          })
        )
      );
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.prank(mockTerminalAddress);
      _delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(
            JBTokens.ETH,
            tiers[0].price * 2 + tiers[1].price,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      uint256 _tokenId = _generateTokenId(1, 1);
      vm.expectRevert(JBTiered721Delegate.TRANSFERS_PAUSED.selector);
      vm.prank(msg.sender);
      IERC721(_delegate).transferFrom(msg.sender, beneficiary, _tokenId);
    }
    // If FC has the pause transfer flag but the delegate flag 'pausable' is false, transfer are not paused
    function testJBTieredNFTRewardDelegate_beforeTransferHook_pauseFlagOverrideFundingCycleTransferPaused()
      public
    {
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      vm.mockCall(
        mockJBFundingCycleStore,
        abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
        abi.encode(
          JBFundingCycle({
            number: 1,
            configuration: block.timestamp,
            basedOn: 0,
            start: block.timestamp,
            duration: 600,
            weight: 10e18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0)),
            metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
              JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                  allowSetTerminals: false,
                  allowSetController: false,
                  pauseTransfers: false
                }),
                reservedRate: 5000, //50%
                redemptionRate: 5000, //50%
                ballotRedemptionRate: 5000,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(0),
                metadata: 1 // 001_2
              })
            )
          })
        )
      );
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      bool _allowOverspending;
      uint16[] memory _tierIdsToMint = new uint16[](3);
      _tierIdsToMint[0] = 1;
      _tierIdsToMint[1] = 1;
      _tierIdsToMint[2] = 2;
      bytes memory _metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        _allowOverspending,
        _tierIdsToMint
      );
      vm.prank(mockTerminalAddress);
      _delegate.didPay(
        JBDidPayData(
          msg.sender,
          projectId,
          0,
          JBTokenAmount(
            JBTokens.ETH,
            tiers[0].price * 2 + tiers[1].price,
            18,
            JBCurrencies.ETH
          ),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          msg.sender,
          false,
          '',
          _metadata
        )
      );
      uint256 _tokenId = _generateTokenId(1, 1);
      vm.prank(msg.sender);
      IERC721(_delegate).transferFrom(msg.sender, beneficiary, _tokenId);
      // Check: token transferred
      assertEq(IERC721(_delegate).ownerOf(_tokenId), beneficiary);
    }
    function testJBTieredNFTRewardDelegate_beforeTransferHook_redeemEvenIfTransferPausedInFundingCycle()
      public
    {
      address _holder = address(bytes20(keccak256('_holder')));
      vm.mockCall(
        mockJBFundingCycleStore,
        abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
        abi.encode(
          JBFundingCycle({
            number: 1,
            configuration: block.timestamp,
            basedOn: 0,
            start: block.timestamp,
            duration: 600,
            weight: 10e18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0)),
            metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
              JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                  allowSetTerminals: false,
                  allowSetController: false,
                  pauseTransfers: false
                }),
                reservedRate: 5000, //50%
                redemptionRate: 5000, //50%
                ballotRedemptionRate: 5000,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(0),
                metadata: 1 // 001_2
              })
            )
          })
        )
      );
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      // Metadata to mint
      bytes memory metadata;
      {
        // Craft the metadata: mint the specified tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(1); // 1 indexed
        metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
          true,
          rawMetadata
        );
      }
      // We mint the NFTs otherwise the voting balance does not get incremented
      // which leads to underflow on redeem
      vm.prank(mockTerminalAddress);
      _delegate.didPay(
        JBDidPayData(
          _holder,
          projectId,
          0,
          JBTokenAmount(JBTokens.ETH, tiers[0].price, 18, JBCurrencies.ETH),
          JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
          0,
          _holder,
          false,
          '',
          metadata
        )
      );
      uint256[] memory _tokenToRedeem = new uint256[](1);
      _tokenToRedeem[0] = _generateTokenId(1, 1);
      vm.prank(mockTerminalAddress);
      _delegate.didRedeem(
        JBDidRedeemData({
          holder: _holder,
          projectId: projectId,
          currentFundingCycleConfiguration: 1,
          projectTokenCount: 0,
          reclaimedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          forwardedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }), // 0 fwd to delegate
          beneficiary: payable(_holder),
          memo: 'thy shall redeem',
          metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenToRedeem)
        })
      );
      // Balance should be 0 again
      assertEq(_delegate.balanceOf(_holder), 0);
    }
    // ----------------
    //    Redemption
    // ----------------
    function testJBTieredNFTRewardDelegate_redeemParams_returnsCorrectAmount() public {
      uint256 _overflow = 10e18;
      uint256 _redemptionRate = 4000; // 40%
      uint256 _weight;
      uint256 _totalWeight;
      JB721TierParams[] memory _tierParams = new JB721TierParams[](10);
      // Temp for constructor
      for (uint256 i; i < 10; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Set 10 tiers, with half supply minted for each
      for (uint256 i = 1; i <= 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i,
          JBStored721Tier({
            price: uint104(i * 10),
           remainingQuantity: uint32(10 * i - 5 * i),
            initialQuantity: uint32(10 * i),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
          })
        );
        _totalWeight += (10 * i - 5 * i) * i * 10;
      }
      // Redeem based on holding 1 NFT in each of the 5 first tiers
      uint256[] memory _tokenList = new uint256[](5);
      for (uint256 i; i < 5; i++) {
        uint256 _tokenId = _generateTokenId(i + 1, 1);
        _delegate.ForTest_setOwnerOf(_tokenId, beneficiary);
        _tokenList[i] = _tokenId;
        _weight += (i + 1) * 10;
      }
      (
        uint256 reclaimAmount,
        string memory memo,
        JBRedemptionDelegateAllocation[] memory _returnedDelegate
      ) = _delegate.redeemParams(
          JBRedeemParamsData({
            terminal: IJBPaymentTerminal(address(0)),
            holder: beneficiary,
            projectId: projectId,
            currentFundingCycleConfiguration: 0,
            tokenCount: 0,
            totalSupply: 0,
            overflow: _overflow,
            reclaimAmount: JBTokenAmount({
              token: address(0),
              value: 0,
              decimals: 18,
              currency: JBCurrencies.ETH
            }),
            useTotalOverflow: true,
            redemptionRate: _redemptionRate,
            memo: 'plz gib',
            metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
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
      assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }
    function testJBTieredNFTRewardDelegate_redeemParams_returnsZeroAmountIfReservedRateIsZero()
      public
    {
      uint256 _overflow = 10e18;
      uint256 _redemptionRate = 0;
      uint256 _weight;
      uint256 _totalWeight;
      JB721TierParams[] memory _tierParams = new JB721TierParams[](10);
      // Temp for constructor
      for (uint256 i; i < 10; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Set 10 tiers, with half supply minted for each
      for (uint256 i = 1; i <= 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i,
          JBStored721Tier({
            price: uint104(i * 10),
           remainingQuantity: uint32(10 * i - 5 * i),
            initialQuantity: uint32(10 * i),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
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
      (
        uint256 reclaimAmount,
        string memory memo,
        JBRedemptionDelegateAllocation[] memory _returnedDelegate
      ) = _delegate.redeemParams(
          JBRedeemParamsData({
            terminal: IJBPaymentTerminal(address(0)),
            holder: beneficiary,
            projectId: projectId,
            currentFundingCycleConfiguration: 0,
            tokenCount: 0,
            totalSupply: 0,
            overflow: _overflow,
            reclaimAmount: JBTokenAmount({
              token: address(0),
              value: 0,
              decimals: 18,
              currency: JBCurrencies.ETH
            }),
            useTotalOverflow: true,
            redemptionRate: _redemptionRate,
            memo: 'plz gib',
            metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
          })
        );
      assertEq(reclaimAmount, 0);
      assertEq(memo, 'plz gib');
      assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }
    function testJBTieredNFTRewardDelegate_redeemParams_returnsPartOfOverflowOwnedIfRedemptionRateIsMaximum()
      public
    {
      uint256 _overflow = 10e18;
      uint256 _redemptionRate = _accessJBLib.MAX_RESERVED_RATE(); // 40%
      uint256 _weight;
      uint256 _totalWeight;
      JB721TierParams[] memory _tierParams = new JB721TierParams[](10);
      // Temp for constructor
      for (uint256 i; i < 10; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(i + 1),
          reservedRate: uint16(0),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Set 10 tiers, with half supply minted for each
      for (uint256 i = 1; i <= 10; i++) {
        _delegate.test_store().ForTest_setTier(
          address(_delegate),
          i,
          JBStored721Tier({
            price: uint104(i * 10),
           remainingQuantity: uint32(10 * i - 5 * i),
            initialQuantity: uint32(10 * i),
            votingUnits: uint16(0),
            reservedRate: uint16(0),
            category: uint24(100),
            allowManualMint: false,
            transfersPausable: false,
            useVotingUnits: false
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
      (
        uint256 reclaimAmount,
        string memory memo,
        JBRedemptionDelegateAllocation[] memory _returnedDelegate
      ) = _delegate.redeemParams(
          JBRedeemParamsData({
            terminal: IJBPaymentTerminal(address(0)),
            holder: beneficiary,
            projectId: projectId,
            currentFundingCycleConfiguration: 0,
            tokenCount: 0,
            totalSupply: 0,
            overflow: _overflow,
            reclaimAmount: JBTokenAmount({
              token: address(0),
              value: 0,
              decimals: 18,
              currency: JBCurrencies.ETH
            }),
            useTotalOverflow: true,
            redemptionRate: _redemptionRate,
            memo: 'plz gib',
            metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
          })
        );
      // Portion of the overflow accessible (pro rata weight held)
      uint256 _base = PRBMath.mulDiv(_overflow, _weight, _totalWeight);
      assertEq(reclaimAmount, _base);
      assertEq(memo, 'plz gib');
      assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }
    function testJBTieredNFTRewardDelegate_redeemParams_revertIfNonZeroTokenCount(uint256 _tokenCount)
      public
    {
      vm.assume(_tokenCount > 0);
      vm.expectRevert(abi.encodeWithSelector(JB721Delegate.UNEXPECTED_TOKEN_REDEEMED.selector));
      delegate.redeemParams(
        JBRedeemParamsData({
          terminal: IJBPaymentTerminal(address(0)),
          holder: beneficiary,
          projectId: projectId,
          currentFundingCycleConfiguration: 0,
          tokenCount: _tokenCount,
          totalSupply: 0,
          overflow: 100,
          reclaimAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          useTotalOverflow: true,
          redemptionRate: 100,
          memo: '',
          metadata: new bytes(0)
        })
      );
    }
    function testJBTieredNFTRewardDelegate_didRedeem_burnRedeemedNFT(uint16 _numberOfNFT) public {
      address _holder = address(bytes20(keccak256('_holder')));
      // Has to all fit in tier 1
      vm.assume(_numberOfNFT < tiers[0].initialQuantity);
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      uint256[] memory _tokenList = new uint256[](_numberOfNFT);
      // TODO: mint different tiers
      for (uint256 i; i < _numberOfNFT; i++) {
        bytes memory _metadata;
        {
          uint16[] memory _tierIdsToMint = new uint16[](1);
          _tierIdsToMint[0] = 1;
          _metadata = abi.encode(
            bytes32(0),
            bytes32(0),
            type(IJB721Delegate).interfaceId,
            false,
            _tierIdsToMint
          );
        }
        // We mint the NFTs otherwise the voting balance does not get incremented
        // which leads to underflow on redeem
        vm.prank(mockTerminalAddress);
        _delegate.didPay(
          JBDidPayData(
            _holder,
            projectId,
            0,
            JBTokenAmount(JBTokens.ETH, tiers[0].price, 18, JBCurrencies.ETH),
            JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
            0,
            _holder,
            false,
            '',
            _metadata
          )
        );
        _tokenList[i] = _generateTokenId(1, i + 1);
        // Assert that a new NFT was minted
        assertEq(_delegate.balanceOf(_holder), i + 1);
      }
      vm.prank(mockTerminalAddress);
      _delegate.didRedeem(
        JBDidRedeemData({
          holder: _holder,
          projectId: projectId,
          currentFundingCycleConfiguration: 1,
          projectTokenCount: 0,
          reclaimedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          forwardedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }), // 0 fwd to delegate
          beneficiary: payable(_holder),
          memo: 'thy shall redeem',
          metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
        })
      );
      // Balance should be 0 again
      assertEq(_delegate.balanceOf(_holder), 0);
      // Burn should be counted (_numberOfNft in first tier)
      for (uint256 i; i < _numberOfNFT; i++)
        assertEq(_ForTest_store.numberOfBurnedFor(address(_delegate), 1), _numberOfNFT);
    }
    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfInvalidCategorySortOrder(
      uint8 initialNumberOfTiers,
      uint8 numberTiersToAdd
    ) public {
       // Include adding X new tiers when 0 preexisting ones
      vm.assume(initialNumberOfTiers < 30);
      vm.assume(numberTiersToAdd > 1);
      JB721TierParams[] memory _tierParams = new JB721TierParams[](initialNumberOfTiers);
      for (uint256 i; i < initialNumberOfTiers; i++) {
        _tierParams[i] = JB721TierParams({
          price: uint104((i + 1) * 10),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
      }
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        _tierParams,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: true,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      JB721TierParams[] memory _tierParamsToAdd = new JB721TierParams[](numberTiersToAdd);
      for (uint256 i; i < numberTiersToAdd; i++) {
        _tierParamsToAdd[i] = JB721TierParams({
          price: uint104((i + 1) * 100),
          initialQuantity: uint32(100),
          votingUnits: uint16(0),
          reservedRate: uint16(i),
          reservedTokenBeneficiary: reserveBeneficiary,
          encodedIPFSUri: tokenUris[0],
          category: uint24(100),
          allowManualMint: false,
          shouldUseReservedTokenBeneficiaryAsDefault: false,
          transfersPausable: false,
          useVotingUnits: false
        });
    }
      _tierParamsToAdd[numberTiersToAdd - 1].category = uint8(99);
      vm.expectRevert(
        abi.encodeWithSelector(JBTiered721DelegateStore.INVALID_CATEGORY_SORT_ORDER.selector)
      );
      vm.prank(owner);
      _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }
    function testJBTieredNFTRewardDelegate_didRedeem_revertIfNotCorrectProjectId(
      uint8 _wrongProjectId
    ) public {
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
      vm.expectRevert(abi.encodeWithSelector(JB721Delegate.INVALID_REDEMPTION_EVENT.selector));
      vm.prank(mockTerminalAddress);
      delegate.didRedeem(
        JBDidRedeemData({
          holder: _holder,
          projectId: _wrongProjectId,
          currentFundingCycleConfiguration: 1,
          projectTokenCount: 0,
          reclaimedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          forwardedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }), //sv 0 fwd to delegate
          beneficiary: payable(_holder),
          memo: 'thy shall redeem',
          metadata: abi.encode(type(IJB721Delegate).interfaceId, _tokenList)
        })
      );
    }
    function testJBTieredNFTRewardDelegate_didRedeem_revertIfCallerIsNotATerminalOfTheProject()
      public
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
      vm.expectRevert(abi.encodeWithSelector(JB721Delegate.INVALID_REDEMPTION_EVENT.selector));
      vm.prank(mockTerminalAddress);
      delegate.didRedeem(
        JBDidRedeemData({
          holder: _holder,
          projectId: projectId,
          currentFundingCycleConfiguration: 1,
          projectTokenCount: 0,
          reclaimedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          forwardedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }), // 0 fwd to delegate
          beneficiary: payable(_holder),
          memo: 'thy shall redeem',
          metadata: abi.encode(type(IJB721Delegate).interfaceId, _tokenList)
        })
      );
    }
    function testJBTieredNFTRewardDelegate_didRedeem_RevertIfWrongHolder(
      address _wrongHolder,
      uint8 tokenId
    ) public {
      address _holder = address(bytes20(keccak256('_holder')));
      vm.assume(_holder != _wrongHolder);
      vm.assume(tokenId != 0);
      ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
      ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJBTokenUriResolver(mockTokenUriResolver),
        contractUri,
        tiers,
        IJBTiered721DelegateStore(address(_ForTest_store)),
        JBTiered721Flags({
          preventOverspending: false,
          lockReservedTokenChanges: false,
          lockVotingUnitChanges: false,
          lockManualMintingChanges: true
        })
      );
      _delegate.transferOwnership(owner);
      _delegate.ForTest_setOwnerOf(tokenId, _holder);
      uint256[] memory _tokenList = new uint256[](1);
      _tokenList[0] = tokenId;
      // Mock the directory call
      vm.mockCall(
        address(mockJBDirectory),
        abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
        abi.encode(true)
      );
      vm.expectRevert(abi.encodeWithSelector(JB721Delegate.UNAUTHORIZED_TOKEN.selector, tokenId));
      vm.prank(mockTerminalAddress);
      _delegate.didRedeem(
        JBDidRedeemData({
          holder: _wrongHolder,
          projectId: projectId,
          currentFundingCycleConfiguration: 1,
          projectTokenCount: 0,
          reclaimedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }),
          forwardedAmount: JBTokenAmount({
            token: address(0),
            value: 0,
            decimals: 18,
            currency: JBCurrencies.ETH
          }), // 0 fwd to delegate
          beneficiary: payable(_wrongHolder),
          memo: 'thy shall redeem',
          metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
        })
      );
    }
    // ----------------
    // Internal helpers
    // ----------------
    // JB721Tier comparison
    function assertEq(JB721Tier memory first, JB721Tier memory second) private {
      assertEq(first.id, second.id);
      assertEq(first.price, second.price);
      assertEq(first.remainingQuantity, second.remainingQuantity);
      assertEq(first.initialQuantity, second.initialQuantity);
      assertEq(first.votingUnits, second.votingUnits);
      assertEq(first.reservedRate, second.reservedRate);
      assertEq(first.reservedTokenBeneficiary, second.reservedTokenBeneficiary);
      assertEq(first.encodedIPFSUri, second.encodedIPFSUri);
    }
    // JB721Tier Array comparison
    function assertEq(JB721Tier[] memory first, JB721Tier[] memory second) private {
      assertEq(first.length, second.length);
      for (uint256 i; i < first.length; i++) {
        assertEq(first[i].id, second[i].id);
        assertEq(first[i].price, second[i].price);
        assertEq(first[i].remainingQuantity, second[i].remainingQuantity);
        assertEq(first[i].initialQuantity, second[i].initialQuantity);
        assertEq(first[i].votingUnits, second[i].votingUnits);
        assertEq(first[i].reservedRate, second[i].reservedRate);
        assertEq(first[i].reservedTokenBeneficiary, second[i].reservedTokenBeneficiary);
        assertEq(first[i].encodedIPFSUri, second[i].encodedIPFSUri);
      }
    }
    // Generate tokenId's based on token number and tier
    function _generateTokenId(uint256 _tierId, uint256 _tokenNumber)
      internal
      pure
      returns (uint256)
    {
      return (_tierId * 1_000_000_000) + _tokenNumber;
    }
    // Check if every elements from smol are in bigg
    function _isIn(JB721Tier[] memory smol, JB721Tier[] memory bigg) private returns (bool) {
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
    function _compareTiers(JB721Tier memory first, JB721Tier memory second)
      private
      pure
      returns (bool)
    {
      return (first.id == second.id &&
        first.price == second.price &&
        first.remainingQuantity == second.remainingQuantity &&
        first.initialQuantity == second.initialQuantity &&
        first.votingUnits == second.votingUnits &&
        first.reservedRate == second.reservedRate &&
        first.reservedTokenBeneficiary == second.reservedTokenBeneficiary &&
        first.encodedIPFSUri == second.encodedIPFSUri &&
        keccak256(abi.encodePacked(first.resolvedUri)) == keccak256(abi.encodePacked(second.resolvedUri)));
    }
    function _sortArray(uint256[] memory _in) internal pure returns (uint256[] memory) {
      for (uint256 i; i < _in.length; i++) {
        uint256 minIndex = i;
        uint256 minValue = _in[i];
        for (uint256 j = i; j < _in.length; j++) {
          if (_in[j] < minValue) {
            minIndex = j;
            minValue = _in[j];
          }
        }
        if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
      }
      return _in;
    }
    function _sortArray(uint16[] memory _in) internal pure returns (uint16[] memory) {
      for (uint256 i; i < _in.length; i++) {
        uint256 minIndex = i;
        uint16 minValue = _in[i];
        for (uint256 j = i; j < _in.length; j++) {
          if (_in[j] < minValue) {
            minIndex = j;
            minValue = _in[j];
          }
        }
        if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
      }
      return _in;
    }
    function _sortArray(uint8[] memory _in) internal pure returns (uint8[] memory) {
      for (uint256 i; i < _in.length; i++) {
        uint256 minIndex = i;
        uint8 minValue = _in[i];
        for (uint256 j = i; j < _in.length; j++) {
          if (_in[j] < minValue) {
            minIndex = j;
            minValue = _in[j];
          }
        }
        if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
      }
      return _in;
    }
  }
  // ForTest to manually set some internalt nested values
  interface IJBTiered721DelegateStore_ForTest is IJBTiered721DelegateStore {
    function ForTest_dumpTiersList(address _nft) external view returns (JB721Tier[] memory _tiers);
    function ForTest_setTier(
      address _delegate,
      uint256 index,
      JBStored721Tier calldata newTier
    ) external;
    function ForTest_setBalanceOf(
      address _delegate,
      address holder,
      uint256 tier,
      uint256 balance
    ) external;
    function ForTest_setReservesMintedFor(
      address _delegate,
      uint256 tier,
      uint256 amount
    ) external;
    function ForTest_setIsTierRemoved(address _delegate, uint256 _tokenId) external;
  }
  contract ForTest_JBTiered721Delegate is JBTiered721Delegate {
    IJBTiered721DelegateStore_ForTest public test_store;
    constructor(
      uint256 _projectId,
      IJBDirectory _directory,
      string memory _name,
      string memory _symbol,
      IJBFundingCycleStore _fundingCycleStore,
      string memory _baseUri,
      IJBTokenUriResolver _tokenUriResolver,
      string memory _contractUri,
      JB721TierParams[] memory _tiers,
      IJBTiered721DelegateStore _test_store,
      JBTiered721Flags memory _flags
    )
      // The directory is also an IJBOperatable
      JBTiered721Delegate(_directory.projects(), IJBOperatable(address(_directory)).operatorStore())
    {
      // Disable the safety check to not allow initializing the original contract
       codeOrigin = address(0);
       JBTiered721Delegate.initialize(
        _projectId,
        _directory,
        _name,
        _symbol,
        _fundingCycleStore,
        _baseUri,
        _tokenUriResolver,
        _contractUri,
        JB721PricingParams({tiers: _tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
        _test_store,
        _flags
      );
      test_store = IJBTiered721DelegateStore_ForTest(address(_test_store));
    }
    function ForTest_setOwnerOf(uint256 tokenId, address _owner) public {
      _owners[tokenId] = _owner;
    }
  }
  contract ForTest_JBTiered721DelegateStore is
    JBTiered721DelegateStore,
    IJBTiered721DelegateStore_ForTest
  {
    using JBBitmap for mapping(uint256=>uint256);
    using JBBitmap for JBBitmapWord;
    function ForTest_dumpTiersList(address _nft)
      public
      view
      override
      returns (JB721Tier[] memory _tiers)
    {
      // Keep a reference to the max tier ID.
      uint256 _maxTierId = maxTierIdOf[_nft];
      // Initialize an array with the appropriate length.
      _tiers = new JB721Tier[](_maxTierId);
      // Count the number of included tiers.
      uint256 _numberOfIncludedTiers;
      // Get a reference to the index being iterated on, starting with the starting index.
      uint256 _currentSortIndex = _firstSortedTierIdOf(_nft, 0);
      // Keep a reference to the tier being iterated on.
      JBStored721Tier memory _storedTier;
      // Make the sorted array.
      while (_currentSortIndex != 0 && _numberOfIncludedTiers < _maxTierId) {
        _storedTier = _storedTierOf[_nft][_currentSortIndex];
        // Add the tier to the array being returned.
        _tiers[_numberOfIncludedTiers++] = JB721Tier({
          id: _currentSortIndex,
          price: _storedTier.price,
          remainingQuantity: _storedTier.remainingQuantity,
          initialQuantity: _storedTier.initialQuantity,
          votingUnits: _storedTier.votingUnits,
          reservedRate: _storedTier.reservedRate,
          reservedTokenBeneficiary: reservedTokenBeneficiaryOf(_nft, _currentSortIndex),
          encodedIPFSUri: encodedIPFSUriOf[_nft][_currentSortIndex],
          category: _storedTier.category,
          allowManualMint: _storedTier.allowManualMint,
          transfersPausable: _storedTier.transfersPausable,
          resolvedUri: ""
        });
        // Set the next sort index.
        _currentSortIndex = _nextSortedTierIdOf(_nft, _currentSortIndex, _maxTierId);
      }
      // Drop the empty tiers at the end of the array (coming from maxTierIdOf which *might* be bigger than actual bigger tier)
      for (uint256 i = _tiers.length - 1; i >= 0; i--) {
        if (_tiers[i].id == 0) {
          assembly ("memory-safe") {
            mstore(_tiers, sub(mload(_tiers), 1))
          }
        } else break;
      }
    }
    function ForTest_setTier(
      address _delegate,
      uint256 index,
      JBStored721Tier calldata newTier
    ) public override {
      _storedTierOf[address(_delegate)][index] = newTier;
    }
    function ForTest_setBalanceOf(
      address _delegate,
      address holder,
      uint256 tier,
      uint256 balance
    ) public override {
      tierBalanceOf[address(_delegate)][holder][tier] = balance;
    }
    function ForTest_setReservesMintedFor(
      address _delegate,
      uint256 tier,
      uint256 amount
    ) public override {
      numberOfReservesMintedFor[address(_delegate)][tier] = amount;
    }
    function ForTest_setIsTierRemoved(address _delegate, uint256 _tokenId) public override {
      _isTierRemovedBitmapWord[_delegate].removeTier(_tokenId);
    }
}
