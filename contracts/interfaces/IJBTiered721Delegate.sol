// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleStore.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol';
import './../structs/JB721TierParams.sol';
import './../structs/JBTiered721MintReservesForTiersData.sol';
import './IJBTiered721DelegateStore.sol';

interface IJBTiered721Delegate {
  event Mint(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    uint256 totalAmountContributed,
    address caller
  );

  event MintReservedToken(
    uint256 indexed tokenId,
    uint256 indexed tierId,
    address indexed beneficiary,
    address caller
  );

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

  event AddTier(uint256 indexed tierId, JB721TierParams data, address caller);

  event RemoveTier(uint256 indexed tierId, address caller);

  event SetDefaultReservedTokenBeneficiary(address indexed beneficiary, address caller);

  function store() external view returns (IJBTiered721DelegateStore);

  function fundingCycleStore() external view returns (IJBFundingCycleStore);

  function prices() external view returns (IJBPrices);

  function tierCurrency() external view returns (uint256);

  function tierDecimals() external view returns (uint256);

  function contractURI() external view returns (string memory);

  function creditsOf(address _address) external view returns (uint256);

  function firstOwnerOf(uint256 _tokenId) external view returns (address);

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

  function adjustTiers(JB721TierParams[] memory _tierDataToAdd, uint256[] memory _tierIdsToRemove)
    external;

  function setTierDelegate(address _delegatee, uint256 _tierId) external;

  function mintReservesFor(JBTiered721MintReservesForTiersData[] memory _mintReservesForTiersData)
    external;

  function mintReservesFor(uint256 _tierId, uint256 _count) external;

  function setDefaultReservedTokenBeneficiary(address _beneficiary) external;
}
