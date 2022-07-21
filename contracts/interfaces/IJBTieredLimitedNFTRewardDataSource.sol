// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import './../structs/JBNFTRewardTierData.sol';
import './../structs/JBNFTRewardTier.sol';

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

  event AddTier(uint256 indexed tierId, JBNFTRewardTierData data, address caller);

  event RemoveTier(uint256 indexed tierId, address caller);

  event SetReservedTokenBeneficiary(address indexed beneficiary, address caller);

  function contributionToken() external view returns (address);

  function numberOfTiers() external view returns (uint256);

  function shouldMintByDefault() external view returns (bool);

  function isTierRemoved(uint256 _tierId) external view returns (bool);

  function tierBalanceOf(address _account, uint256 _tier) external view returns (uint256);

  function numberOfReservesMintedFor(uint256 _tierId) external view returns (uint256);

  function getVotingUnits(address _account) external view returns (uint256 units);

  function tierIdOfToken(uint256 _tokenId) external view returns (uint256);

  function tier(uint256 _id) external view returns (JBNFTRewardTier memory _tier);

  function tiers() external view returns (JBNFTRewardTier[] memory tiers);

  function reservedTokenBeneficiary() external view returns (address);

  function adjustTiers(
    JBNFTRewardTierData[] memory _tierDataToAdd,
    uint256[] memory _tierIdsToRemove
  ) external;

  function numberOfReservedTokensOutstandingFor(uint256 _tierId) external view returns (uint256);

  function mintReservesFor(uint256 _tierId, uint256 _count) external;

  function setReservedTokenBeneficiary(address _beneficiary) external;
}
