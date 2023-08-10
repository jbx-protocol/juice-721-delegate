pragma solidity ^0.8.16;

import "../E2E.t.sol";

import "../../JBTiered721GovernanceDelegate.sol";
import "../../abstract/ERC721.sol";

contract TestJBTiered721DelegateGovernance is TestJBTieredNFTRewardDelegateE2E {
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    function testMintAndTransferGlobalVotingUnits(uint256 _tier, bool _recipientDelegated) public {
        address _user = address(bytes20(keccak256("user")));
        address _userFren = address(bytes20(keccak256("user_fren")));
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        // _tier has to be a valid tier (0-indexed)
        _tier = bound(_tier, 0, tiered721DeployerData.pricing.tiers.length - 1);
        // Set the governance type to tiered
        tiered721DeployerData.governanceType = JB721GovernanceType.ONCHAIN;
        JBTiered721GovernanceDelegate _delegate;
        // to handle stack too deep
        {
            uint256 projectId =
                deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
            // Get the dataSource
            _delegate = JBTiered721GovernanceDelegate(_jbFundingCycleStore.currentOf(projectId).dataSource());
            uint256 _payAmount = tiered721DeployerData.pricing.tiers[_tier].price;
            assertEq(_delegate.delegates(_user), address(0));
            vm.prank(_user);
            _delegate.delegate(_user);
            // Pay and mint an NFT
            vm.deal(_user, _payAmount);
            vm.prank(_user);
            bytes memory _delegateMetadata;
            {
                // Craft the metadata: mint the specified tier
                uint16[] memory rawMetadata = new uint16[](1);
                rawMetadata[0] = uint16(_tier + 1); // 1 indexed

                bytes[] memory _data = new bytes[](1);
                _data[0] = abi.encode(true, rawMetadata);

                // Pass the delegate id
                bytes4[] memory _ids = new bytes4[](1);
                _ids[0] = payMetadataDelegateId;

                // Generate the metadata
                _delegateMetadata = _delegate.createMetadata(_ids, _data);
            }
            _jbETHPaymentTerminal.pay{value: _payAmount}(
                projectId, 100, address(0), _user, 0, false, "Take my money!", _delegateMetadata
            );
        }
        // Assert that the user received the votingUnits
        assertEq(_delegate.getVotes(_user), tiered721DeployerData.pricing.tiers[_tier].votingUnits);
        uint256 _frenExpectedVotes = 0;
        // Have the user delegate to themselves
        if (_recipientDelegated) {
            _frenExpectedVotes = tiered721DeployerData.pricing.tiers[_tier].votingUnits;
            vm.prank(_userFren);
            _delegate.delegate(_userFren);
        }
        // Transfer NFT to fren
        vm.prank(_user);
        ERC721(address(_delegate)).transferFrom(_user, _userFren, _generateTokenId(_tier + 1, 1));
        // Assert that the user lost their voting units
        assertEq(_delegate.getVotes(_user), 0);
        // Assert that fren received the voting units
        assertEq(_delegate.getVotes(_userFren), _frenExpectedVotes);
    }

    function testMintAndDelegateVotingUnits(uint256 _tier, bool _selfDelegateBeforeReceive) public {
        address _user = address(bytes20(keccak256("user")));
        address _userFren = address(bytes20(keccak256("user_fren")));

        JBDeployTiered721DelegateData memory tiered721DeployerData;
        uint256 projectId;
        JBTiered721GovernanceDelegate _delegate;
        
        {
        JBLaunchProjectData memory launchProjectData;
        (tiered721DeployerData, launchProjectData) =
            createData();
        // _tier has to be a valid tier (0-indexed)
        _tier = bound(_tier, 0, tiered721DeployerData.pricing.tiers.length - 1);
        // Set the governance type to tiered
        tiered721DeployerData.governanceType = JB721GovernanceType.ONCHAIN;
        projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // Get the dataSource
        _delegate =
            JBTiered721GovernanceDelegate(_jbFundingCycleStore.currentOf(projectId).dataSource());
        // Delegate NFT to fren
        vm.startPrank(_user);
        _delegate.delegate(_userFren);
        // Delegate NFT to self
        if (_selfDelegateBeforeReceive) {
            _delegate.delegate(_user);
        }
        }

        {
        uint256 _payAmount = tiered721DeployerData.pricing.tiers[_tier].price;

        // Craft the metadata: mint the specified tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(_tier + 1); // 1 indexed

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        bytes memory _delegateMetadata = _delegate.createMetadata(_ids, _data);

        // Pay and mint an NFT
        vm.deal(_user, _payAmount);
        _jbETHPaymentTerminal.pay{value: _payAmount}(
            projectId, 100, address(0), _user, 0, false, "Take my money!", _delegateMetadata
        );
        }
        // Delegate NFT to self
        if (!_selfDelegateBeforeReceive) {
            _delegate.delegate(_user);
        }
        // Assert that the user received the votingUnits
        assertEq(_delegate.getVotes(_user), tiered721DeployerData.pricing.tiers[_tier].votingUnits);
        // Delegate to the users fren
        _delegate.delegate(_userFren);
        vm.stopPrank();
        // Assert that the user lost their voting units
        assertEq(_delegate.getVotes(_user), 0);
        // Assert that fren received the voting units
        assertEq(_delegate.getVotes(_userFren), tiered721DeployerData.pricing.tiers[_tier].votingUnits);
    }
}
