// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ITokenSupplyDetails {
  function totalSupply() external view returns (uint256);

  function tokenSupplyOf(uint256) external view returns (uint256);

  function totalOwnerBalanceOf(address) external view returns (uint256);

  function ownerTokenBalanceOf(address, uint256) external view returns (uint256);
}
