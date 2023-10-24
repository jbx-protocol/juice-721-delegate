pragma solidity ^0.8.16;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_redemption_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_redeemParams_returnsCorrectAmount() public {
        uint256 _weight;
        uint256 _totalWeight;
        ForTest_JBTiered721Delegate _delegate;
        {
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
                })
            );
            _totalWeight += (10 * i - 5 * i) * i * 10;
        }
        } 
        // Redeem based on holding 1 NFT in each of the 5 first tiers
        uint256[] memory _tokenList = new uint256[](5);
        for (uint256 i; i < 5; i++) {
            uint256 _tokenId = _generateTokenId(i + 1, 1);
            _delegate.ForTest_setOwnerOf(_tokenId, beneficiary);
            _tokenList[i] = _tokenId;
            _weight += (i + 1) * 10;
        }

        //Build the metadata with the tiers to redee
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_tokenList);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = REDEEM_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        (uint256 reclaimAmount, string memory memo, JBRedemptionDelegateAllocation3_1_1[] memory _returnedDelegate) =
        _delegate.redeemParams(
            JBRedeemParamsData({
                terminal: IJBPaymentTerminal(address(0)),
                holder: beneficiary,
                projectId: projectId,
                currentFundingCycleConfiguration: 0,
                tokenCount: 0,
                totalSupply: 0,
                overflow: OVERFLOW,
                reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                useTotalOverflow: true,
                redemptionRate: REDEMPTION_RATE,
                memo: "plz gib",
                metadata: _delegateMetadata
            })
        ); 

        // Portion of the overflow accessible (pro rata weight held)
        uint256 _base = mulDiv(OVERFLOW, _weight, _totalWeight);
        uint256 _claimableOverflow = mulDiv(
            _base,
            REDEMPTION_RATE + mulDiv(_weight, MAX_RESERVED_RATE() - REDEMPTION_RATE, _totalWeight),
            MAX_RESERVED_RATE()
        );
        assertEq(reclaimAmount, _claimableOverflow);
        assertEq(memo, "plz gib");
        assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }

    function testJBTieredNFTRewardDelegate_redeemParams_returnsZeroAmountIfReservedRateIsZero() public {
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
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
        (uint256 reclaimAmount, string memory memo, JBRedemptionDelegateAllocation3_1_1[] memory _returnedDelegate) =
        _delegate.redeemParams(
            JBRedeemParamsData({
                terminal: IJBPaymentTerminal(address(0)),
                holder: beneficiary,
                projectId: projectId,
                currentFundingCycleConfiguration: 0,
                tokenCount: 0,
                totalSupply: 0,
                overflow: _overflow,
                reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                useTotalOverflow: true,
                redemptionRate: _redemptionRate,
                memo: "plz gib",
                metadata: abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, _tokenList)
            })
        );
        assertEq(reclaimAmount, 0);
        assertEq(memo, "plz gib");
        assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }

    function testJBTieredNFTRewardDelegate_redeemParams_returnsPartOfOverflowOwnedIfRedemptionRateIsMaximum() public {
        uint256 _weight;
        uint256 _totalWeight;

        ForTest_JBTiered721Delegate _delegate;
        {
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
                        packedBools: _delegate.test_store().ForTest_packBools(false, false, false)
                    })
                );
                _totalWeight += (10 * i - 5 * i) * i * 10;
            }
        }
        uint256 reclaimAmount;
        JBRedemptionDelegateAllocation3_1_1[] memory _returnedDelegate;
        string memory memo;
        {
            // Redeem based on holding 1 NFT in each of the 5 first tiers
            uint256[] memory _tokenList = new uint256[](5);
            for (uint256 i; i < 5; i++) {
                _delegate.ForTest_setOwnerOf(_generateTokenId(i + 1, 1), beneficiary);
                _tokenList[i] = _generateTokenId(i + 1, 1);
                _weight += (i + 1) * 10;
            }

            //Build the metadata with the tiers to redee
            bytes[] memory _data = new bytes[](1);
            _data[0] = abi.encode(_tokenList);

            // Pass the delegate id
            bytes4[] memory _ids = new bytes4[](1);
            _ids[0] = REDEEM_DELEGATE_ID;

            // Generate the metadata
            bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
            (reclaimAmount, memo, _returnedDelegate) =
            _delegate.redeemParams(
                JBRedeemParamsData({
                    terminal: IJBPaymentTerminal(address(0)),
                    holder: beneficiary,
                    projectId: projectId,
                    currentFundingCycleConfiguration: 0,
                    tokenCount: 0,
                    totalSupply: 0,
                    overflow: OVERFLOW,
                    reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                    useTotalOverflow: true,
                    redemptionRate: REDEMPTION_RATE,
                    memo: "plz gib",
                    metadata: _delegateMetadata
                })
            );
            }
            // Portion of the overflow accessible (pro rata weight held)
            uint256 _base = mulDiv(OVERFLOW, _weight, _totalWeight);
            assertEq(reclaimAmount, _base);
            assertEq(memo, "plz gib");
            assertEq(address(_returnedDelegate[0].delegate), address(_delegate));
    }

    function testJBTieredNFTRewardDelegate_redeemParams_revertIfNonZeroTokenCount(uint256 _tokenCount) public {
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
                reclaimAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                useTotalOverflow: true,
                redemptionRate: 100,
                memo: "",
                metadata: new bytes(0)
            })
        );
    }

    function testJBTieredNFTRewardDelegate_didRedeem_burnRedeemedNFT(uint16 _numberOfNFT) public {
        address _holder = address(bytes20(keccak256("_holder")));
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
        // Mock the directory call
        vm.mockCall(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );
        uint256[] memory _tokenList = new uint256[](_numberOfNFT);
        // TODO: mint different tiers
        bytes memory _delegateMetadata;
        bytes[] memory _data;
        bytes4[] memory _ids;
        for (uint256 i; i < _numberOfNFT; i++) {
            {
                uint16[] memory _tierIdsToMint = new uint16[](1);
                _tierIdsToMint[0] = 1;

                // Build the metadata with the tiers to mint and the overspending flag
                _data = new bytes[](1);
                _data[0] = abi.encode(false, _tierIdsToMint);

                // Pass the delegate id
                _ids = new bytes4[](1);
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
            _tokenList[i] = _generateTokenId(1, i + 1);
            // Assert that a new NFT was minted
            assertEq(_delegate.balanceOf(_holder), i + 1);
        }

        // Build the metadata with the tiers to redeem
        _data = new bytes[](1);
        _data[0] = abi.encode(_tokenList);

        // Pass the delegate id
        _ids = new bytes4[](1);
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
        // Burn should be counted (_numberOfNft in first tier)
        for (uint256 i; i < _numberOfNFT; i++) {
            assertEq(_ForTest_store.numberOfBurnedFor(address(_delegate), 1), _numberOfNFT);
        }
    }

    function testJBTieredNFTRewardDelegate_didRedeem_revertIfNotCorrectProjectId(uint8 _wrongProjectId) public {
        vm.assume(_wrongProjectId != projectId);
        address _holder = address(bytes20(keccak256("_holder")));
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
            JBDidRedeemData3_1_1({
                holder: _holder,
                projectId: _wrongProjectId,
                currentFundingCycleConfiguration: 1,
                projectTokenCount: 0,
                reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                forwardedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}), //sv 0 fwd to delegate
                beneficiary: payable(_holder),
                memo: "thy shall redeem",
                dataSourceMetadata: bytes(""),
                redeemerMetadata: abi.encode(type(IJBTiered721Delegate).interfaceId, _tokenList)
            })
        );
    }

    function testJBTieredNFTRewardDelegate_didRedeem_revertIfCallerIsNotATerminalOfTheProject() public {
        address _holder = address(bytes20(keccak256("_holder")));
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
                redeemerMetadata: abi.encode(type(IJBTiered721Delegate).interfaceId, _tokenList)
            })
        );
    }

    function testJBTieredNFTRewardDelegate_didRedeem_RevertIfWrongHolder(address _wrongHolder, uint8 tokenId) public {
        address _holder = address(bytes20(keccak256("_holder")));
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
        _delegate.ForTest_setOwnerOf(tokenId, _holder);
        uint256[] memory _tokenList = new uint256[](1);
        _tokenList[0] = tokenId;

        //Build the metadata with the tiers to redee
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_tokenList);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = REDEEM_DELEGATE_ID;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // Mock the directory call
        vm.mockCall(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );
        vm.expectRevert(abi.encodeWithSelector(JB721Delegate.UNAUTHORIZED_TOKEN.selector, tokenId));
        vm.prank(mockTerminalAddress);
        _delegate.didRedeem(
            JBDidRedeemData3_1_1({
                holder: _wrongHolder,
                projectId: projectId,
                currentFundingCycleConfiguration: 1,
                projectTokenCount: 0,
                reclaimedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}),
                forwardedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: JBCurrencies.ETH}), // 0 fwd to delegate
                beneficiary: payable(_wrongHolder),
                memo: "thy shall redeem",
                dataSourceMetadata: bytes(""),
                redeemerMetadata: _delegateMetadata
            })
        );
    }
}