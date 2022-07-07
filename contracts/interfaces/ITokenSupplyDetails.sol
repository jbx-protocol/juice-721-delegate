// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IToken721UriResolver.sol';

interface ITokenSupplyDetails {
  function totalSupply() external view returns (uint256);

  function tokenSupply(uint256) external view returns (uint256);

  function totalOwnerBalance(address) external view returns (uint256);

  function ownerTokenBalance(address, uint256) external view returns (uint256);
}
