pragma solidity ^0.8.16;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_getters_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiers(uint256 numberOfTiers) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);

        (JB721TierParams[] memory _tierParams, JB721Tier[] memory _tiers) = _createTiers(defaultTierParams, numberOfTiers);

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(_tierParams);

        assertTrue(
            _isIn(_delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, numberOfTiers), _tiers)
        );
        assertTrue(
            _isIn(_tiers, _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, numberOfTiers))
        );
    }

    function testJBTieredNFTRewardDelegate_pricing_packingFunctionsAsExpected(
        uint48 _currency,
        uint48 _decimals,
        address _prices
    ) public {
        JBDeployTiered721DelegateData memory delegateData = JBDeployTiered721DelegateData(
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: tiers, currency: _currency, decimals: _decimals, prices: IJBPrices(_prices)}),
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

        JBTiered721Delegate _delegate =
            JBTiered721Delegate(address(jbDelegateDeployer.deployDelegateFor(projectId, delegateData)));

        (uint256 __currency, uint256 __decimals, IJBPrices __prices) = _delegate.pricingContext();
        assertEq(__currency, uint256(_currency));
        assertEq(__decimals, uint256(_decimals));
        assertEq(address(__prices), _prices);
    }

    function testJBTieredNFTRewardDelegate_bools_packingFunctionsAsExpected(bool _a, bool _b, bool _c) public {
        ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
        uint8 _packed = _ForTest_store.ForTest_packBools(_a, _b, _c);
        (bool __a, bool __b, bool __c) = _ForTest_store.ForTest_unpackBools(_packed);
        assertEq(_a, __a);
        assertEq(_b, __b);
        assertEq(_c, __c);
    }

    function testJBTieredNFTRewardDelegate_tiers_returnsAllTiersWithResolver(uint256 numberOfTiers) public {
        numberOfTiers = bound(numberOfTiers, 0, 30);
        JB721TierParams[] memory _tierParams = new JB721TierParams[](numberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](numberOfTiers);
        address _mockTokenUriResolver = address(bytes20(keccak256("mockTokenUriResolver")));
        for (uint256 i; i < numberOfTiers; i++) {
            uint256 _zeroToken = _generateTokenId(i + 1, 0);
            string memory uri = string(abi.encodePacked("resolverURI", _zeroToken));
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
            IJB721TokenUriResolver(_mockTokenUriResolver),
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

        for (uint256 i; i < numberOfTiers; i++) {
            uint256 _zeroToken = _generateTokenId(i + 1, 0);
            string memory uri = string(abi.encodePacked("resolverURI", _zeroToken));
            // Mock the URI resolver call
            mockAndExpect(
                _mockTokenUriResolver,
                abi.encodeWithSelector(IJB721TokenUriResolver.tokenUriOf.selector, address(_delegate), _zeroToken),
                abi.encode(uri)
            );
        }

        _delegate.transferOwnership(owner);

        assertTrue(
            _isIn(_delegate.test_store().tiersOf(address(_delegate), new uint256[](0), true, 0, numberOfTiers), _tiers)
        );
        assertTrue(
            _isIn(_tiers, _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), true, 0, numberOfTiers))
        );
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
        ForTest_JBTiered721Delegate _delegate;
        {
            ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
            _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJB721TokenUriResolver(mockTokenUriResolver),
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
        }
        _delegate.transferOwnership(owner);
        _delegate.test_store().ForTest_setIsTierRemoved(address(_delegate), firstRemovedTier);
        _delegate.test_store().ForTest_setIsTierRemoved(address(_delegate), secondRemovedTier);
        // Check: tier array returned is resized
        assertEq(
            _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, numberOfTiers).length,
            numberOfTiers - 2
        );
        // Check: all and only the non-removed tiers are in the tier array returned
        assertTrue(
            _isIn(
                _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, numberOfTiers),
                _nonRemovedTiers
            )
        );
        assertTrue(
            _isIn(
                _nonRemovedTiers,
                _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, numberOfTiers)
            )
        );
    }

    function testJBTieredNFTRewardDelegate_tier_returnsTheGivenTier(uint256 numberOfTiers, uint16 givenTier) public {
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
        }
        // Check: correct tier, if exist?
        if (givenTier <= numberOfTiers && givenTier != 0) {
            assertEq(_delegate.test_store().tierOf(address(_delegate), givenTier, false), _tiers[givenTier - 1]);
        } else {
            assertEq( // empty tier if not?
                _delegate.test_store().tierOf(address(_delegate), givenTier, false),
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
    }

    function testJBTieredNFTRewardDelegate_totalSupply_returnsTotalSupply(uint256 numberOfTiers) public {
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
                })
            );
        }
        assertEq(_delegate.test_store().totalSupplyOf(address(_delegate)), ((numberOfTiers * (numberOfTiers + 1)) / 2));
    }

    function testJBTieredNFTRewardDelegate_balanceOf_returnsCompleteBalance(uint256 numberOfTiers, address holder)
        public
    {
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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

    function testJBTieredNFTRewardDelegate_numberOfReservedTokensOutstandingFor_returnsOutstandingReserved() public {
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }
        for (uint256 i; i < 10; i++) {
            assertEq(_delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), i + 1), 3);
        }
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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

    function testJBTieredNFTRewardDelegate_tierIdOfToken_returnsCorrectTierNumber(uint16 _tierId, uint16 _tokenNumber)
        public
    {
        vm.assume(_tierId > 0 && _tokenNumber > 0);
        uint256 tokenId = _generateTokenId(_tierId, _tokenNumber);
        assertEq(delegate.store().tierOfTokenId(address(delegate), tokenId, false).id, _tierId);
    }

    function testJBTieredNFTRewardDelegate_tokenURI_returnsCorrectUriIfResolverUsed(uint256 tokenId, address holder)
        public
    {
        vm.assume(holder != address(0));
        ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
        address _mockTokenUriResolver = address(bytes20(keccak256("mockTokenUriResolver")));
        ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJB721TokenUriResolver(_mockTokenUriResolver),
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
        mockAndExpect(
            _mockTokenUriResolver,
            abi.encodeWithSelector(IJB721TokenUriResolver.tokenUriOf.selector, address(_delegate), tokenId),
            abi.encode("resolverURI")
        );
        _delegate.ForTest_setOwnerOf(tokenId, holder);
        assertEq(_delegate.tokenURI(tokenId), "resolverURI");
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
        IJB721TokenUriResolver(address(0)),
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
            if (isMinted) {
                _delegate.ForTest_setOwnerOf(tokenId, holder);
            }
            assertEq(_delegate.tokenURI(tokenId), string(abi.encodePacked(baseUri, theoricHashes[i - 1])));
        }
    }

    function testJBTieredNFTRewardDelegate_setEncodedIPFSUriOf_returnsCorrectUriIfEncodedAdded() public {
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
        IJB721TokenUriResolver(address(0)),
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
        _delegate.setMetadata("", "", IJB721TokenUriResolver(address(0)), 1, tokenUris[1]);
        assertEq(_delegate.tokenURI(tokenId), string(abi.encodePacked(baseUri, theoricHashes[1])));
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
        assertEq(_delegate.test_store().redemptionWeightOf(address(_delegate), _tierToGetWeightOf), _theoreticalWeight);
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
        mockAndExpect(mockJBProjects, abi.encodeWithSelector(IERC721.ownerOf.selector, projectId), abi.encode(owner));
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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

    function testJBTieredNFTRewardDelegate_firstOwnerOf_shouldReturnAddressZeroIfNotMinted(uint256 tokenId) public {
        ForTest_JBTiered721DelegateStore _ForTest_store = new ForTest_JBTiered721DelegateStore();
        ForTest_JBTiered721Delegate _delegate = new ForTest_JBTiered721Delegate(
        projectId,
        IJBDirectory(mockJBDirectory),
        name,
        symbol,
        IJBFundingCycleStore(mockJBFundingCycleStore),
        baseUri,
        IJB721TokenUriResolver(mockTokenUriResolver),
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

    function testJBTieredNFTRewardDelegate_constructor_deployIfNoEmptyInitialQuantity(uint256 nbTiers) public {
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
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
        assertEq(address(_delegate.store().tokenUriResolverOf(address(_delegate))), mockTokenUriResolver);
        assertEq(_delegate.contractURI(), contractUri);
        assertEq(_delegate.owner(), owner);
        assertTrue(_isIn(_delegate.store().tiersOf(address(_delegate), new uint256[](0), false, 0, nbTiers), _tiers)); // Order is not insured
        assertTrue(_isIn(_tiers, _delegate.store().tiersOf(address(_delegate), new uint256[](0), false, 0, nbTiers)));
    }

    function testJBTieredNFTRewardDelegate_constructor_revertDeploymentIfOneEmptyInitialQuantity(
        uint256 nbTiers,
        uint256 errorIndex
    ) public {
        nbTiers = bound(nbTiers, 1, 20);
        errorIndex = bound(errorIndex, 0, nbTiers - 1);
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
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
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
}