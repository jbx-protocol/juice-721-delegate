// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../structs/JBDeployTiered721DelegateData.sol';
import './IJBTiered721Delegate.sol';

interface IJBTiered721DelegateDeployer {
  event DelegateDeployed(uint256 indexed projectId, IJBTiered721Delegate newDelegate);

  function deployDelegateFor(
    uint256 _projectId,
    JBDeployTiered721DelegateData memory _deployTieredNFTRewardDelegateData
  ) external returns (IJBTiered721Delegate delegate);
}
