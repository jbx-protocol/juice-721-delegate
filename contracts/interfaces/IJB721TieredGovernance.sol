// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IJBTiered721DelegateStore.sol';
import './IJBTiered721Delegate.sol';

interface IJB721TieredGovernance is IJBTiered721Delegate {
  
  event TierDelegateChanged(
    address indexed delegator,
    address indexed fromDelegate,
    address indexed toDelegate,
    uint256 tierId,
    address caller
  );

  event TierDelegateVotesChanged(
    address indexed delegate,
    uint256 indexed tierId,
    uint256 previousBalance,
    uint256 newBalance,
    address callre
  );

  function getTierDelegate(address _account, uint256 _tier) external view returns (address);

  function getTierVotes(address _account, uint256 _tier) external view returns (uint256);

  function getPastTierVotes(
    address _account,
    uint256 _tier,
    uint256 _blockNumber
  ) external view returns (uint256);

  function getTierTotalVotes(uint256 _tier) external view returns (uint256);

  function getPastTierTotalVotes(uint256 _tier, uint256 _blockNumber)
    external
    view
    returns (uint256);

  function setTierDelegate(address _delegatee, uint256 _tierId) external;
}
