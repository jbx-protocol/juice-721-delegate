pragma solidity ^0.8.16;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_adjustTier_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_tiers_adjustTier_remove_tiers_multiple_times(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    ) public {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);
        
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(initialNumberOfTiers);
        
        // Create new tiers to add
        (JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) = _createTiers(
            defaultTierParams,
            numberOfFloorTiersToAdd,
            initialNumberOfTiers,
            floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_delegate, _tiersLeft, 2, _tiersParams);

        // remove another 2 tiers but don't add any new ones
        _addDeleteTiers(_delegate, _tiersLeft, 2, new JB721TierParams[](0));

        // Fecth max 100 tiers (will downsize)
        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }   
    }

    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise_after_tiers_have_been_cleaned(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    ) public {
        initialNumberOfTiers = bound(initialNumberOfTiers, 3, 14);
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 1, 15);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        uint256 _currentNumberOfTiers = initialNumberOfTiers;

        (JB721TierParams[] memory _tiersParamsToAdd, JB721Tier[] memory _tiersToAdd) = _createTiers(
            defaultTierParams,
            numberOfFloorTiersToAdd,
            initialNumberOfTiers,
            floorTiersToAdd);

        _currentNumberOfTiers = _addDeleteTiers(_delegate, _currentNumberOfTiers, 0, _tiersParamsToAdd);
        _currentNumberOfTiers = _addDeleteTiers(_delegate, _currentNumberOfTiers, 2, _tiersParamsToAdd);

        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );

        assertEq(_storedTiers.length, _currentNumberOfTiers, "Length mismatch");
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }
    }

    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    ) public {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);
        
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(initialNumberOfTiers);
        
        // Create new tiers to add
        (JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) = _createTiers(
            defaultTierParams,
            numberOfFloorTiersToAdd,
            initialNumberOfTiers,
            floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_delegate, _tiersLeft, 0, _tiersParams);

        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers_With_Non_Sequential_Categories(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    ) public {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);
        
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory _defaultStoredTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );
        
        // Create new tiers to add
        (JB721TierParams[] memory _tiersParamsToAdd, JB721Tier[] memory _tiersToAdd) = _createTiers(
            defaultTierParams,
            numberOfFloorTiersToAdd,
            initialNumberOfTiers,
            floorTiersToAdd,
            2);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_delegate, _tiersLeft, 0, _tiersParamsToAdd);

        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );

        // Check: Expected number of tiers?
        assertEq(_storedTiers.length, _tiersLeft, "Length mismatch");
        
        // Check: Are all tiers in the new tiers (unsorted)?
        // assertTrue(_isIn(_defaultStoredTiers, _storedTiers), "Original not included"); // Original tiers
        assertTrue(_isIn(_tiersToAdd, _storedTiers), "New not included"); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error");
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    ) public {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);
        
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory _intialTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );
        
        // Create new tiers to add
        (JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiersAdded) = _createTiers(
            defaultTierParams,
            numberOfFloorTiersToAdd,
            initialNumberOfTiers,
            floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _addDeleteTiers(_delegate, _tiersLeft, 0, _tiersParams);

        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), new uint256[](0), false, 0, 100
        );

        // Check: Expected number of tiers?
        assertEq(_storedTiers.length, _intialTiers.length + _tiersAdded.length, "Length mismatch");

        // Check: Are all tiers in the new tiers (unsorted)?
        assertTrue(_isIn(_intialTiers, _storedTiers), "original tiers not found"); // Original tiers
        assertTrue(_isIn(_tiersAdded, _storedTiers), "new tiers not found"); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            assertLe(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error");
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
        JBTiered721Delegate _delegate;
        {
            JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
            vm.etch(delegate_i, address(delegate).code);
            _delegate = JBTiered721Delegate(delegate_i);
            _delegate.initialize(
                projectId,
                name,
                symbol,
                IJBFundingCycleStore(mockJBFundingCycleStore),
                baseUri,
                IJB721TokenUriResolver(mockTokenUriResolver),
                contractUri,
                JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
                address(_delegate), new uint256[](0), false, 0, initialNumberOfTiers + floorTiersToAdd.length * 2
            );
            assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2);
        }
        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 101;
        JB721Tier[] memory _stored101Tiers =
            _delegate.store().tiersOf(address(_delegate), _categories, false, 0, floorTiersToAdd.length * 2);
        assertEq(_stored101Tiers.length, floorTiersToAdd.length * 2);
        _categories[0] = 100;
        JB721Tier[] memory _stored100Tiers =
            _delegate.store().tiersOf(address(_delegate), _categories, false, 0, initialNumberOfTiers);
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
        JBTiered721Delegate _delegate;
        {
            JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
            vm.etch(delegate_i, address(delegate).code);
            _delegate = JBTiered721Delegate(delegate_i);
            _delegate.initialize(
                projectId,
                name,
                symbol,
                IJBFundingCycleStore(mockJBFundingCycleStore),
                baseUri,
                IJB721TokenUriResolver(mockTokenUriResolver),
                contractUri,
                JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
            address(_delegate), new uint256[](0), false, 0, initialNumberOfTiers + floorTiersToAdd.length * 2
        );
        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 102;
        JB721Tier[] memory _stored102Tiers =
            _delegate.store().tiersOf(address(_delegate), _categories, false, 0, floorTiersToAdd.length);
        assertEq(_stored102Tiers.length, floorTiersToAdd.length);
        for (uint256 i = 0; i < _stored102Tiers.length; i++) {
            assertEq(_stored102Tiers[i].category, uint8(102));
        }
        _categories[0] = 101;
        JB721Tier[] memory _stored101Tiers =
            _delegate.store().tiersOf(address(_delegate), _categories, false, 0, floorTiersToAdd.length);
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
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 0;
        JB721Tier[] memory _allStoredTiers =
            _delegate.store().tiersOf(address(_delegate), _categories, false, 0, initialNumberOfTiers);
        assertEq(_allStoredTiers.length, initialNumberOfTiers);
        for (uint256 i = 0; i < _allStoredTiers.length; i++) {
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

        JBTiered721Delegate _delegate;
        {
            JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
            vm.etch(delegate_i, address(delegate).code);
            _delegate = JBTiered721Delegate(delegate_i);
            _delegate.initialize(
                projectId,
                name,
                symbol,
                IJBFundingCycleStore(mockJBFundingCycleStore),
                baseUri,
                IJB721TokenUriResolver(mockTokenUriResolver),
                contractUri,
                JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
        uint256[] memory _categories = new uint256[](3);
        _categories[0] = 102;
        _categories[1] = 100;
        _categories[2] = 101;
        JB721Tier[] memory _allStoredTiers = _delegate.store().tiersOf(
            address(_delegate), _categories, false, 0, initialNumberOfTiers + floorTiersToAdd.length * 2
        );
        assertEq(_allStoredTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2);
        uint256 tier_100_max_index = _allStoredTiers.length - floorTiersToAdd.length;
        for (uint256 i = 0; i < floorTiersToAdd.length; i++) {
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
        JBTiered721Delegate _delegate;
        {
            JBTiered721DelegateStore _store = new JBTiered721DelegateStore();
            vm.etch(delegate_i, address(delegate).code);
            _delegate = JBTiered721Delegate(delegate_i);
            _delegate.initialize(
                projectId,
                name,
                symbol,
                IJBFundingCycleStore(mockJBFundingCycleStore),
                baseUri,
                IJB721TokenUriResolver(mockTokenUriResolver),
                contractUri,
                JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 101;
        JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
            address(_delegate), _categories, false, 0, initialNumberOfTiers + floorTiersToAdd.length
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
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
            bool _invalidTier;
            if (_newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (_newTierCandidate == tiersToRemove[j]) {
                        _invalidTier = true;
                        break;
                    }
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
        // Will be resized later
        JB721TierParams[] memory tierParamsRemaining = new JB721TierParams[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < _tiers.length; i++) {
            tierParamsRemaining[i] = _tierParams[i];
            tiersRemaining[i] = _tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool _swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
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
            JB721Tier[] memory _storedTiers =
                _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, finalNumberOfTiers);
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
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
            false,
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                price: uint104(0),
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
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.VOTING_UNITS_NOT_ALLOWED.selector));
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.RESERVED_RATE_NOT_ALLOWED.selector));
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
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: _tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
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
            _delegate.store().tiersOf(address(_delegate), new uint256[](0), false, 0, initialNumberOfTiers).length,
            initialNumberOfTiers - 1
        );
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
                useVotingUnits: true
            });
        }
        _tierParamsToAdd[numberTiersToAdd - 1].category = uint8(99);
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INVALID_CATEGORY_SORT_ORDER.selector));
        vm.prank(owner);
        _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfMoreVotingUnitsNotAllowedWithPriceChange(
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
        IJB721TokenUriResolver(mockTokenUriResolver),
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
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.VOTING_UNITS_NOT_ALLOWED.selector));
        vm.prank(owner);
        _delegate.adjustTiers(_tierParamsToAdd, new uint256[](0));
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
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
            bool _invalidTier;
            if (_newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (_newTierCandidate == tiersToRemove[j]) {
                        _invalidTier = true;
                        break;
                    }
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
        // Will be resized later
        JB721TierParams[] memory tierParamsRemaining = new JB721TierParams[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < _tiers.length; i++) {
            tierParamsRemaining[i] = _tierParams[i];
            tiersRemaining[i] = _tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool _swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
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
            }
            if (!_swappedAndPopped) i++;
        }
        vm.prank(owner);
        _delegate.adjustTiers(new JB721TierParams[](0), tiersToRemove);
        JB721Tier[] memory _tiersListDump = _delegate.test_store().ForTest_dumpTiersList(address(_delegate));
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
}