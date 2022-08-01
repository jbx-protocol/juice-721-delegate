// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './../structs/JBNFTRewardTierData.sol';
import './../structs/JBNFTRewardTier.sol';

interface IJBTieredLimitedNFTRewardDataSourceStore {
  event AddTier(uint256 indexed tierId, JBNFTRewardTierData data, address caller);
  event RemoveTier(uint256 indexed tierId, address caller);

  function totalSupply(address _nft) external view returns (uint256);

  function balanceOf(address _nft, address _owner) external view returns (uint256);

  function numberOfTiers(address _nft) external view returns (uint256);

  function tiers(address _nft) external view returns (JBNFTRewardTier[] memory tiers);

  function tier(address _nft, uint256 _id) external view returns (JBNFTRewardTier memory tier);

  function tierBalanceOf(
    address _nft,
    address _owner,
    uint256 _tier
  ) external view returns (uint256);

  function tierOfTokenId(address _nft, uint256 _tokenId)
    external
    view
    returns (JBNFTRewardTier memory tier);

  function tierIdOfToken(uint256 _tokenId) external pure returns (uint256);

  // function redemptionWeightOf(address _nft, uint256[] memory _tokenIds)
  //   external
  //   view
  //   returns (uint256 weight);

  // function totalRedemptionWeight(address _nft) external view returns (uint256 weight);

  function numberOfReservedTokensOutstandingFor(address _nft, uint256 _tierId)
    external
    view
    returns (uint256);

  function numberOfReservesMintedFor(address _nft, uint256 _tierId) external view returns (uint256);

  function isTierRemoved(address _nft, uint256 _tierId) external view returns (bool);

  function votingUnitsOf(address _nft, address _account) external view returns (uint256 units);

  function reservedTokenBeneficiary(address _nft) external view returns (address);

  function recordAddTierData(JBNFTRewardTierData[] memory _tierData, bool _constructorTiers)
    external;

  function recordMintReservesFor(uint256 _tierId, uint256 _count)
    external
    returns (uint256[] memory tokenIds);

  function recordMintBestAvailableTier(
    uint256 _amount,
    address _beneficiary,
    bool _expectMint
  )
    external
    returns (
      uint256 tokenId,
      uint256 tierId,
      uint256 leftoverAmount
    );

  function recordSetReservedTokenBeneficiary(address _beneficiary) external;

  function recordMint(
    uint256 _amount,
    uint256 _tierId,
    address _beneficiary
  ) external returns (uint256 tokenId, uint256 leftoverAmount);

  function recordRemoveTierIds(uint256[] memory _tierIds) external;
}
