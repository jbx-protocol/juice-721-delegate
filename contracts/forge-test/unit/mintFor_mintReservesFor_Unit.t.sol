pragma solidity ^0.8.16;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_mintFor_mintReservesFor_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_mintReservesFor_mintReservedToken() public {
        // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
        // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
        uint256 initialQuantity = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reservedRate = 4000;
        uint256 nbTiers = 3;

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(nbTiers);
        
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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), tier);

            for (uint256 token = 1; token <= mintable; token++) {
                vm.expectEmit(true, true, true, true, address(_delegate));
                emit MintReservedToken(_generateTokenId(tier, totalMinted + token), tier, reserveBeneficiary, owner);
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

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(nbTiers);

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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }

        uint256 _totalMintable; // Keep a running counter

        JBTiered721MintReservesForTiersData[] memory _reservedToMint =
            new JBTiered721MintReservesForTiersData[](nbTiers);

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), tier);
            _reservedToMint[tier - 1] = JBTiered721MintReservesForTiersData({tierId: tier, count: mintable});
            _totalMintable += mintable;
            for (uint256 token = 1; token <= mintable; token++) {
                uint256 _tokenNonce = totalMinted + token; // Avoid stack too deep
                vm.expectEmit(true, true, true, true, address(_delegate));
                emit MintReservedToken(_generateTokenId(tier, _tokenNonce), tier, reserveBeneficiary, owner);
            }
        }

        vm.prank(owner);
        _delegate.mintReservesFor(_reservedToMint);

        // Check balance
        assertEq(_delegate.balanceOf(reserveBeneficiary), _totalMintable);
    }

    function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfReservedMintingIsPausedInFundingCycle() public {
        // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reservedRate is 40% (4000/10000)
        // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
        uint256 initialQuantity = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reservedRate = 4000;
        uint256 nbTiers = 3;

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
                            metadata: 2 // == 010_2
                        })
                        )
                })
            )
        );

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(nbTiers);

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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), tier);
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

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(10);

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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }

        for (uint256 i = 1; i <= 10; i++) {
            // Get the amount that we can mint successfully
            uint256 amount = _delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), i);
            // Increase it by 1 to cause an error
            amount++;
            vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector));
            vm.prank(owner);
            _delegate.mintReservesFor(i, amount);
        }
    }

    function testJBTieredNFTRewardDelegate_use_default_reserved_token_beneficiary() public {
        uint256 initialQuantity = 200;
        uint256 totalMinted = 120;
        uint256 reservedRate = 9;

        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(10);

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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
        }
    }

    function testJBTieredNFTRewardDelegate_no_reserved_rate_if_no_beneficiary_set() public {
        uint256 initialQuantity = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 10;
        uint256 reservedRate = 9;

        reserveBeneficiary = address(0);
        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(10);

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
                    packedBools: _delegate.test_store().ForTest_packBools(false, false, true)
                })
            );
            _delegate.test_store().ForTest_setReservesMintedFor(address(_delegate), i + 1, reservedMinted);
        }

        // fetching existing tiers
        JB721Tier[] memory _storedTiers = _delegate.test_store().tiersOf(address(_delegate), new uint256[](0), false, 0, 10);

        // making sure reserved rate is 0
        for (uint256 i; i < 10; i++) {
            assertEq(_storedTiers[i].reservedRate, 0, "wrong reserved rate");
        }
        for (uint256 i; i < 10; i++) {
            assertEq(_delegate.test_store().numberOfReservedTokensOutstandingFor(address(_delegate), i + 1), 0, "wrong outstanding reserved tokens");
        }
    }

    function testJBTieredNFTRewardDelegate_mintFor_mintArrayOfTiers() public {
        uint256 nbTiers = 3;
        
        defaultTierParams.allowManualMint = true;
        defaultTierParams.reservedRate = 0;
        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(nbTiers);

        uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
        for (uint256 i; i < nbTiers; i++) {
            _tiersToMint[i] = uint16(i) + 1;
            _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

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
        uint256 nbTiers = 10;

        uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
        for (uint256 i; i < nbTiers; i++) {
            _tiersToMint[i] = uint16(i) + 1;
            _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

        defaultTierParams.allowManualMint = false;
        ForTest_JBTiered721Delegate _delegate = _initializeForTestDelegate(nbTiers);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.CANT_MINT_MANUALLY.selector));
        _delegate.mintFor(_tiersToMint, beneficiary);
    }
}