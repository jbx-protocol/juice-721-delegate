pragma solidity ^0.8.16;

import '../E2E.t.sol';

import '../../JB721TieredGovernance.sol';

contract TestJBTieredGovernance is TestJBTieredNFTRewardDelegateE2E {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  function testMintAndTransferTieredVotingUnits(uint8 _tier, bool _recipientDelegated) public {
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = JB721GovernanceType.TIERED;
    JB721TieredGovernance _delegate;
    // to handle stack too deep
    {
    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData,
      _jbController
    );

    // Get the dataSource
    _delegate = JB721TieredGovernance(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );

    // _tier has to be a valid tier
    vm.assume(_tier < NFTRewardDeployerData.pricing.tiers.length);
    uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].contributionFloor;

    assertEq(_delegate.getTierDelegate(_user, _tier), address(0));

    vm.prank(_user);
    _delegate.setTierDelegate(_user, _tier + 1);

     bytes memory metadata;
    {
      // Craft the metadata: mint the specified tier
      uint16[] memory rawMetadata = new uint16[](1);
      rawMetadata[0] = uint16(_tier + 1); // 1 indexed
      metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        true,
        rawMetadata
      );
    }

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
    }

    // Assert that the user received the votingUnits
    assertEq(
      _delegate.getTierVotes(_user, _tier + 1),
      NFTRewardDeployerData.pricing.tiers[_tier].votingUnits
    );

    uint256 _frenExpectedVotes = 0;
    // Have the user delegate to themselves
    if (_recipientDelegated) {
      _frenExpectedVotes = NFTRewardDeployerData.pricing.tiers[_tier].votingUnits;

      vm.prank(_userFren);
      _delegate.setTierDelegate(_userFren, _tier + 1);
    }

    // Transfer NFT to fren
    vm.prank(_user);
    ERC721(address(_delegate)).transferFrom(_user, _userFren, _generateTokenId(_tier + 1, 1));

    // Assert that the user lost their voting units
    assertEq(_delegate.getTierVotes(_user, _tier + 1), 0);

    // Assert that fren received the voting units
    assertEq(_delegate.getTierVotes(_userFren, _tier + 1), _frenExpectedVotes);
  }

  function testMintAndDelegateTieredVotingUnits(uint8 _tier, bool _selfDelegateBeforeReceive)
    public
  {
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = JB721GovernanceType.TIERED;

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData,
      _jbController
    );

    // Get the dataSource
    JB721TieredGovernance _delegate = JB721TieredGovernance(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );

    // _tier has to be a valid tier
    vm.assume(_tier < NFTRewardDeployerData.pricing.tiers.length);
    uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].contributionFloor;

    // Delegate NFT to fren
    vm.prank(_user);
    _delegate.setTierDelegate(_userFren, _tier + 1);

    // Delegate NFT to self
    if (_selfDelegateBeforeReceive) {
      vm.prank(_user);
      _delegate.setTierDelegate(_user, _tier + 1);
    }

    bytes memory metadata;
    {
      // Craft the metadata: mint the specified tier
      uint16[] memory rawMetadata = new uint16[](1);
      rawMetadata[0] = uint16(_tier + 1); // 1 indexed
      metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        true,
        rawMetadata
      );
    }

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
      _delegate.setTierDelegate(_user, _tier + 1);
    }

    // Assert that the user received the votingUnits
    assertEq(
      _delegate.getTierVotes(_user, _tier + 1),
      NFTRewardDeployerData.pricing.tiers[_tier].votingUnits
    );

    // Delegate to the users fren
    vm.prank(_user);
    _delegate.setTierDelegate(_userFren, _tier + 1);

    // Assert that the user lost their voting units
    assertEq(_delegate.getTierVotes(_user, _tier + 1), 0);

    // Assert that fren received the voting units
    assertEq(
      _delegate.getTierVotes(_userFren, _tier + 1),
      NFTRewardDeployerData.pricing.tiers[_tier].votingUnits
    );
  }
}
