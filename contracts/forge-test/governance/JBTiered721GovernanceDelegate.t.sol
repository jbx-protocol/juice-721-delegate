pragma solidity ^0.8.16;

import '../E2E.t.sol';

import '../../JBTiered721GovernanceDelegate.sol';

contract TestJBTiered721DelegateGovernance is TestJBTieredNFTRewardDelegateE2E {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  function testMintAndTransferGlobalVotingUnits(uint256 _tier, bool _recipientDelegated) public {
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();
    // _tier has to be a valid tier (0-indexed)
    _tier = bound(_tier, 0, NFTRewardDeployerData.pricing.tiers.length - 1);
    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = JB721GovernanceType.ONCHAIN;
    JBTiered721GovernanceDelegate _delegate;
    // to handle stack too deep
    {
      uint256 projectId = deployer.launchProjectFor(
        _projectOwner,
        NFTRewardDeployerData,
        launchProjectData,
        _jbController
      );
      // Get the dataSource
      _delegate = JBTiered721GovernanceDelegate(
        _jbFundingCycleStore.currentOf(projectId).dataSource()
      );
      uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].price;
      assertEq(_delegate.delegates(_user), address(0));
      vm.prank(_user);
      _delegate.delegate(_user);
      // Pay and mint an NFT
      vm.deal(_user, _payAmount);
      vm.prank(_user);
      bytes memory metadata;
      {
        // Craft the metadata: mint the specified tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(_tier + 1); // 1 indexed
        metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJBTiered721Delegate).interfaceId,
          true,
          rawMetadata
        );
      }
      _jbETHPaymentTerminal.pay{value: _payAmount}(
        projectId,
        100,
        address(0),
        _user,
        0,
        false,
        'Take my money!',
        metadata
      );
    }
    // Assert that the user received the votingUnits
    assertEq(_delegate.getVotes(_user), NFTRewardDeployerData.pricing.tiers[_tier].votingUnits);
    uint256 _frenExpectedVotes = 0;
    // Have the user delegate to themselves
    if (_recipientDelegated) {
      _frenExpectedVotes = NFTRewardDeployerData.pricing.tiers[_tier].votingUnits;
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
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();
    // _tier has to be a valid tier (0-indexed)
    _tier = bound(_tier, 0, NFTRewardDeployerData.pricing.tiers.length - 1);
    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = JB721GovernanceType.ONCHAIN;
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData,
      _jbController
    );
    // Get the dataSource
    JBTiered721GovernanceDelegate _delegate = JBTiered721GovernanceDelegate(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );
    uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].price;
    // Delegate NFT to fren
    vm.prank(_user);
    _delegate.delegate(_userFren);
    // Delegate NFT to self
    if (_selfDelegateBeforeReceive) {
      vm.prank(_user);
      _delegate.delegate(_user);
    }
    // Craft the metadata: mint the specified tier
    uint16[] memory rawMetadata = new uint16[](1);
    rawMetadata[0] = uint16(_tier + 1); // 1 indexed
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJBTiered721Delegate).interfaceId,
      true,
      rawMetadata
    );
    // Pay and mint an NFT
    vm.deal(_user, _payAmount);
    vm.prank(_user);
    _jbETHPaymentTerminal.pay{value: _payAmount}(
      projectId,
      100,
      address(0),
      _user,
      0,
      false,
      'Take my money!',
      metadata
    );
    // Delegate NFT to self
    if (!_selfDelegateBeforeReceive) {
      vm.prank(_user);
      _delegate.delegate(_user);
    }
    // Assert that the user received the votingUnits
    assertEq(_delegate.getVotes(_user), NFTRewardDeployerData.pricing.tiers[_tier].votingUnits);
    // Delegate to the users fren
    vm.prank(_user);
    _delegate.delegate(_userFren);
    // Assert that the user lost their voting units
    assertEq(_delegate.getVotes(_user), 0);
    // Assert that fren received the voting units
    assertEq(_delegate.getVotes(_userFren), NFTRewardDeployerData.pricing.tiers[_tier].votingUnits);
  }
}
