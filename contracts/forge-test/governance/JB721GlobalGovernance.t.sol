pragma solidity ^0.8.16;

import "../E2E.t.sol";

import "../../governance/JB721GlobalGovernance.sol";

contract TestJBGlobalGovernance is TestJBTieredNFTRewardDelegateE2E {
 using JBFundingCycleMetadataResolver for JBFundingCycle;

  function testMintAndTransferGlobalVotingUnits(uint8 _tier, bool _recipientDelegated) public {
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = IJBTiered721DelegateDeployer.GovernanceType.GLOBAL;

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    // Get the dataSource
    JB721GlobalGovernance _delegate = JB721GlobalGovernance(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );

    // _tier has to be a valid tier
    vm.assume(_tier < NFTRewardDeployerData.pricing.tiers.length);
    uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].contributionFloor;

    assertEq(
        _delegate.delegates(_user),
        address(0)
    );

    vm.prank(_user);
    _delegate.delegate(_user);

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
      new bytes(0)
    );

    // Assert that the user received the votingUnits
    assertEq(
      _delegate.getVotes(_user),
      NFTRewardDeployerData.pricing.tiers[_tier].votingUnits
    );

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

  function testMintAndDelegateVotingUnits(uint8 _tier, bool _selfDelegateBeforeReceive) public {
    address _user = address(bytes20(keccak256('user')));
    address _userFren = address(bytes20(keccak256('user_fren')));
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    // Set the governance type to tiered
    NFTRewardDeployerData.governanceType = IJBTiered721DelegateDeployer.GovernanceType.GLOBAL;

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

     // Get the dataSource
    JB721GlobalGovernance _delegate = JB721GlobalGovernance(
      _jbFundingCycleStore.currentOf(projectId).dataSource()
    );

    // _tier has to be a valid tier
    vm.assume(_tier < NFTRewardDeployerData.pricing.tiers.length);
    uint256 _payAmount = NFTRewardDeployerData.pricing.tiers[_tier].contributionFloor;

    // Delegate NFT to fren
    vm.prank(_user);
    _delegate.delegate(_userFren);

    // Delegate NFT to self
    if (_selfDelegateBeforeReceive) {
      vm.prank(_user);
      _delegate.delegate(_user);
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
      new bytes(0)
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