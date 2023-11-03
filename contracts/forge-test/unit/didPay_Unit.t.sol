pragma solidity ^0.8.16;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_didPay_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    // If the amount payed is below the price to receive an NFT the pay should not revert if no metadata passed
    function testJBTieredNFTRewardDelegate_didPay_doesRevertOnAmountBelowPriceIfNoMetadataIfPreventOverspending() public {
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(10, true);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(JBTiered721Delegate.OVERSPENDING.selector));

        vm.prank(mockTerminalAddress);
        _delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price - 1, 18, JBCurrencies.ETH), // 1 wei below the minimum amount
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                new bytes(0),
                new bytes(0)
            )
        );

    }

    // If the amount payed is below the price to receive an NFT the pay should revert if no metadata passed and the allow overspending flag is false.
    function testJBTieredNFTRewardDelegate_didPay_doesNotRevertOnAmountBelowPriceIfNoMetadata() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price - 1, 18, JBCurrencies.ETH), // 1 wei below the minimum amount
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                new bytes(0),
                new bytes(0)
            )
        );

        assertEq(delegate.creditsOf(msg.sender), tiers[0].price - 1);
    }

    // If the amount is above contribution floor and a tier is passed, mint as many corresponding tier as possible
    function testJBTieredNFTRewardDelegate_didPay_mintCorrectTier() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));
        
        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Make sure a new NFT was minted
        assertEq(_totalSupplyBeforePay + 3, delegate.store().totalSupplyOf(address(delegate)));

        // Correct tier has been minted?
        assertEq(delegate.ownerOf(_generateTokenId(1, 1)), msg.sender);
        assertEq(delegate.ownerOf(_generateTokenId(1, 2)), msg.sender);
        assertEq(delegate.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }

    function testJBTieredNFTRewardDelegate_didPay_mintNoneIfNonePassed(uint8 _amount) public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](0);
        bytes memory _metadata = abi.encode(
            bytes32(0), bytes32(0), type(IJBTiered721Delegate).interfaceId, _allowOverspending, _tierIdsToMint
        );

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _metadata
            )
        );

        // Make sure no new NFT was minted if amount >= contribution floor
        assertEq(_totalSupplyBeforePay, delegate.store().totalSupplyOf(address(delegate)));
    }

    function testJBTieredNFTRewardDelegate_didPay_mintTierAndTrackLeftover() public {
        uint256 _leftover = tiers[0].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](1);
        _tierIdsToMint[0] = uint16(1);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // calculating new credits
        uint256 _newCredits = _leftover + delegate.creditsOf(beneficiary);

        vm.expectEmit(true, true, true, true, address(delegate));
        emit AddCredits(_newCredits, _newCredits, beneficiary, mockTerminalAddress);

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
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
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256 _credits = delegate.creditsOf(beneficiary);

        _leftover = _leftover / 2 + _credits; //left over amount

        vm.expectEmit(true, true, true, true, address(delegate));
        emit AddCredits(_leftover - _credits, _leftover, beneficiary, mockTerminalAddress);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                beneficiary,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        uint256 _totalSupplyBefore = delegate.store().totalSupplyOf(address(delegate));
        {
            // We now attempt an additional tier 1 by using the credit we collected from last pay
            uint16[] memory _moreTierIdsToMint = new uint16[](4);
            _moreTierIdsToMint[0] = 1;
            _moreTierIdsToMint[1] = 1;
            _moreTierIdsToMint[2] = 2;
            _moreTierIdsToMint[3] = 1;

            _data[0] = abi.encode(_allowOverspending, _moreTierIdsToMint);

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
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
            JBDidPayData3_1_1(
                beneficiary,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Check: total supply has increased?
        assertEq(_totalSupplyBefore + 4, delegate.store().totalSupplyOf(address(delegate)));

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
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                beneficiary,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        uint256 _totalSupplyBefore = delegate.store().totalSupplyOf(address(delegate));
        uint256 _creditBefore = delegate.creditsOf(beneficiary);

        // Second call will mint another 3 tiers requested BUT not with the credit accumulated
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Check: total supply has increased with the 3 token?
        assertEq(_totalSupplyBefore + 3, delegate.store().totalSupplyOf(address(delegate)));

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
        address _jbPrice = address(bytes20(keccak256("MockJBPrice")));
        vm.etch(_jbPrice, new bytes(1));

        // currency 2 with 9 decimals
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(10, false, 2, 9, _jbPrice);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Mock the price oracle call
        uint256 _amountInEth = (tiers[0].price * 2 + tiers[1].price) * 2;
        mockAndExpect(_jbPrice, abi.encodeCall(IJBPrices.priceFor, (1, 2, 18)), abi.encode(2 * 10 ** 9));

        uint256 _totalSupplyBeforePay = _delegate.store().totalSupplyOf(address(delegate));

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amountInEth, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Make sure a new NFT was minted
        assertEq(_totalSupplyBeforePay + 3, _delegate.store().totalSupplyOf(address(_delegate)));

        // Correct tier has been minted?
        assertEq(_delegate.ownerOf(_generateTokenId(1, 1)), msg.sender);
        assertEq(_delegate.ownerOf(_generateTokenId(1, 2)), msg.sender);
        assertEq(_delegate.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }

    // If the tier has been removed, revert
    function testJBTieredNFTRewardDelegate_didPay_revertIfTierRemoved() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256[] memory _toRemove = new uint256[](1);
        _toRemove[0] = 1;

        vm.prank(owner);
        delegate.adjustTiers(new JB721TierParams[](0), _toRemove);

        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.TIER_REMOVED.selector));

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, delegate.store().totalSupplyOf(address(delegate)));
    }

    function testJBTieredNFTRewardDelegate_didPay_revertIfNonExistingTier(uint256 _invalidTier) public {
        _invalidTier = bound(_invalidTier, tiers.length + 1, type(uint16).max);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](1);
        _tierIdsToMint[0] = uint16(_invalidTier);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256[] memory _toRemove = new uint256[](1);
        _toRemove[0] = 1;

        vm.prank(owner);
        delegate.adjustTiers(new JB721TierParams[](0), _toRemove);

        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INVALID_TIER.selector));

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, delegate.store().totalSupplyOf(address(delegate)));
    }

    // If the amount is not enought to cover all the tiers requested, revert
    function testJBTieredNFTRewardDelegate_didPay_revertIfAmountTooLow() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_AMOUNT.selector));

        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price - 1, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, delegate.store().totalSupplyOf(address(delegate)));
    }

    function testJBTieredNFTRewardDelegate_didPay_revertIfAllowanceRunsOutInParticularTier() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _supplyLeft = tiers[0].initialQuantity;

        while (true) {
            uint256 _totalSupplyBeforePay = delegate.store().totalSupplyOf(address(delegate));

            bool _allowOverspending = true;

            uint16[] memory tierSelected = new uint16[](1);
            tierSelected[0] = 1;

            // Build the metadata with the tiers to mint and the overspending flag
            bytes[] memory _data = new bytes[](1);
            _data[0] = abi.encode(_allowOverspending, tierSelected);

            // Pass the delegate id
            bytes4[] memory _ids = new bytes4[](1);
            _ids[0] = PAY_DELEGATE_ID;

            // Generate the metadata
            bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

            // If there is no supply left this should revert
            if (_supplyLeft == 0) {
                vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.OUT.selector));
            }

            // Perform the pay
            vm.prank(mockTerminalAddress);
            delegate.didPay(
                JBDidPayData3_1_1(
                    msg.sender,
                    projectId,
                    0,
                    JBTokenAmount(JBTokens.ETH, tiers[0].price, 18, JBCurrencies.ETH),
                    JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                    0,
                    msg.sender,
                    false,
                    "",
                    bytes(""),
                    _delegateMetadata
                )
            );
            // Make sure if there was no supply left there was no NFT minted
            if (_supplyLeft == 0) {
                assertEq(delegate.store().totalSupplyOf(address(delegate)), _totalSupplyBeforePay);
                break;
            } else {
                assertEq(delegate.store().totalSupplyOf(address(delegate)), _totalSupplyBeforePay + 1);
            }
            --_supplyLeft;
        }
    }

    function testJBTieredNFTRewardDelegate_didPay_revertIfCallerIsNotATerminalOfProjectId(address _terminal) public {
        vm.assume(_terminal != mockTerminalAddress);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
            abi.encode(false)
        );

        // The caller is the _expectedCaller however the terminal in the calldata is not correct
        vm.prank(_terminal);

        vm.expectRevert(abi.encodeWithSelector(JB721Delegate.INVALID_PAYMENT_EVENT.selector));

        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(address(0), 0, 18, JBCurrencies.ETH),
                JBTokenAmount(address(0), 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                new bytes(0)
            )
        );
    }

    function testJBTieredNFTRewardDelegate_didPay_doNotMintIfNotUsingCorrectToken(address token) public {
        vm.assume(token != JBTokens.ETH);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // The caller is the _expectedCaller however the terminal in the calldata is not correct
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(token, 0, 18, JBCurrencies.ETH),
                JBTokenAmount(token, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                new bytes(0)
            )
        );

        // Check: nothing has been minted
        assertEq(delegate.store().totalSupplyOf(address(delegate)), 0);
    }

    function testJBTieredNFTRewardDelegate_didPay_mintTiersWhenUsingExistingCredits_when_existing_credits_more_than_new_credits(
    ) public {
        uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
        uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256 _credits = delegate.creditsOf(beneficiary);
        _leftover = _leftover / 2 + _credits; //left over amount

        vm.expectEmit(true, true, true, true, address(delegate));
        emit AddCredits(_leftover - _credits, _leftover, beneficiary, mockTerminalAddress);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                beneficiary,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        uint256 _totalSupplyBefore = delegate.store().totalSupplyOf(address(delegate));
        {
            // We now attempt an additional tier 1 by using the credit we collected from last pay
            uint16[] memory _moreTierIdsToMint = new uint16[](1);
            _moreTierIdsToMint[0] = 1;

            _data[0] = abi.encode(_allowOverspending, _moreTierIdsToMint);

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // fetch existing credits
        _credits = delegate.creditsOf(beneficiary);

        // using existing credits to mint
        _leftover = tiers[0].price - 1 - _credits;
        vm.expectEmit(true, true, true, true, address(delegate));
        emit UseCredits(_credits - _leftover, _leftover, beneficiary, mockTerminalAddress);

        // minting with left over credits
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                beneficiary,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price - 1, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        // total supply increases
        assertEq(_totalSupplyBefore + 1, delegate.store().totalSupplyOf(address(delegate)));
    }

    function testJBTieredNFTRewardDelegate_didPay_revertIfUnexpectedLeftover() public {
        uint256 _leftover = tiers[1].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );
        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](0);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        vm.prank(mockTerminalAddress);
        vm.expectRevert(abi.encodeWithSelector(JBTiered721Delegate.OVERSPENDING.selector));
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );
    }

    function testJBTieredNFTRewardDelegate_didPay_revertIfUnexpectedLeftoverAndPrevented(bool _prevent) public {
        uint256 _leftover = tiers[1].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Get the currently selected flags
        JBTiered721Flags memory flags = delegate.store().flagsOf(address(delegate));

        // Modify the prevent
        flags.preventOverspending = _prevent;

        // Mock the call to return the new flags
        mockAndExpect(
            address(delegate.store()),
            abi.encodeWithSelector(IJBTiered721DelegateStore.flagsOf.selector, address(delegate)),
            abi.encode(flags)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](0);

        bytes memory _metadata = abi.encode(
            bytes32(0), bytes32(0), type(IJBTiered721Delegate).interfaceId, _allowOverspending, _tierIdsToMint
        );

        // If prevent is enabled the call should revert, otherwise we should receive credits
        if (_prevent) {
            vm.expectRevert(abi.encodeWithSelector(JBTiered721Delegate.OVERSPENDING.selector));
        } else {
            uint256 _credits = delegate.creditsOf(beneficiary);
            uint256 _stashedCredits = _credits;
            // calculating new credits since _leftover is non zero
            uint256 _newCredits = tiers[0].price + _leftover + _stashedCredits;
            vm.expectEmit(true, true, true, true, address(delegate));
            emit AddCredits(_newCredits - _credits, _newCredits, beneficiary, mockTerminalAddress);
        }
        vm.prank(mockTerminalAddress);
        delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, _amount, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                beneficiary,
                false,
                "",
                bytes(""),
                _metadata
            )
        );
    }

    // Mint are still possible, transfer to other addresses than 0 (ie burn) are reverting (if delegate flag pausable is true)
    function testJBTieredNFTRewardDelegate_beforeTransferHook_revertTransferIfTransferPausedInFundingCycle() public {

        JB721TierParams[] memory _tierParams = new JB721TierParams[](5);

        defaultTierParams.transfersPausable = true;
        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(10);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );


        mockAndExpect(
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

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        uint256 _tokenId = _generateTokenId(1, 1);

        vm.expectRevert(JBTiered721Delegate.TRANSFERS_PAUSED.selector);

        vm.prank(msg.sender);
        IERC721(_delegate).transferFrom(msg.sender, beneficiary, _tokenId);
    }

    // If FC has the pause transfer flag but the delegate flag 'pausable' is false, transfer are not paused
    function testJBTieredNFTRewardDelegate_beforeTransferHook_pauseFlagOverrideFundingCycleTransferPaused() public {

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        mockAndExpect(
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

       JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(10);

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = PAY_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _delegate.didPay(
            JBDidPayData3_1_1(
                msg.sender,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price * 2 + tiers[1].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                msg.sender,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );


        uint256 _tokenId = _generateTokenId(1, 1);
        vm.prank(msg.sender);
        IERC721(_delegate).transferFrom(msg.sender, beneficiary, _tokenId);
        // Check: token transferred
        assertEq(IERC721(_delegate).ownerOf(_tokenId), beneficiary);
    }

    function testJBTieredNFTRewardDelegate_beforeTransferHook_redeemEvenIfTransferPausedInFundingCycle() public {
        address _holder = address(bytes20(keccak256("_holder")));
        mockAndExpect(
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

        JBTiered721Delegate _delegate = _initializeDelegateDefaultTiers(10);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Metadata to mint
        bytes memory _delegateMetadata;
        bytes[] memory _data = new bytes[](1);
        bytes4[] memory _ids = new bytes4[](1);

        {
            // Craft the metadata: mint the specified tier
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(1); // 1 indexed

            // Build the metadata with the tiers to mint and the overspending flag
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the delegate id
            _ids[0] = PAY_DELEGATE_ID;

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // We mint the NFTs otherwise the voting balance does not get incremented
        // which leads to underflow on redeem
        vm.prank(mockTerminalAddress);
        _delegate.didPay(
            JBDidPayData3_1_1(
                _holder,
                projectId,
                0,
                JBTokenAmount(JBTokens.ETH, tiers[0].price, 18, JBCurrencies.ETH),
                JBTokenAmount(JBTokens.ETH, 0, 18, JBCurrencies.ETH), // 0 fwd to delegate
                0,
                _holder,
                false,
                "",
                bytes(""),
                _delegateMetadata
            )
        );

        uint256[] memory _tokenToRedeem = new uint256[](1);
        _tokenToRedeem[0] = _generateTokenId(1, 1);

        // Build the metadata with the tiers to redeem
        _data[0] = abi.encode(_tokenToRedeem);

        // Pass the delegate id
        _ids[0] = REDEEM_DELEGATE_ID;

        // Generate the metadata
        _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _delegate.didRedeem(
            JBDidRedeemData3_1_1({
                holder: _holder,
                projectId: projectId,
                currentFundingCycleConfiguration: 1,
                projectTokenCount: 0,
                reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                forwardedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}), // 0 fwd to delegate
                beneficiary: payable(_holder),
                memo: "thy shall redeem",
                dataSourceMetadata: bytes(""),
                redeemerMetadata: _delegateMetadata
            })
        );
        
        // Balance should be 0 again
        assertEq(_delegate.balanceOf(_holder), 0);
    }
}