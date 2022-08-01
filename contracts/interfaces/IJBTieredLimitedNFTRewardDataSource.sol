// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import './../structs/JBNFTRewardTierData.sol';
import './../structs/JBNFTRewardTier.sol';
import './IJBTieredLimitedNFTRewardDataSourceStore.sol';

interface IJBTieredLimitedNFTRewardDataSource {
  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    uint256 numRewards,
    address caller
  );

  event MintReservedToken(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    address caller
  );

  event SetReservedTokenBeneficiary(address indexed beneficiary, address caller);

  event SetBaseUri(string baseUri, address caller);

  function store() external view returns (IJBTieredLimitedNFTRewardDataSourceStore);

  function adjustTiers(
    JBNFTRewardTierData[] memory _tierDataToAdd,
    uint256[] memory _tierIdsToRemove
  ) external;

  function mintReservesFor(uint256 _tierId, uint256 _count) external;

  function setReservedTokenBeneficiary(address _beneficiary) external;

  function setBaseUri(string memory _baseUri) external;
}
