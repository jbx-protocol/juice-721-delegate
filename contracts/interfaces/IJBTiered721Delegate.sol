// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import './../structs/JB721TierData.sol';
import './../structs/JB721Tier.sol';
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

  event AddTier(uint256 indexed tierId, JB721TierData data, address caller);

  event RemoveTier(uint256 indexed tierId, address caller);

  event SetReservedTokenBeneficiary(address indexed beneficiary, address caller);

  function store() external view returns (IJBTiered721DelegateStore);

  function contributionToken() external view returns (address);

  function contractURI() external view returns (string memory);

  function firstOwnerOf(uint256 _tokenId) external view returns (address);

  function adjustTiers(JB721TierData[] memory _tierDataToAdd, uint256[] memory _tierIdsToRemove)
    external;

  function mintReservesFor(uint256 _tierId, uint256 _count) external;

  function setReservedTokenBeneficiary(address _beneficiary) external;
}
