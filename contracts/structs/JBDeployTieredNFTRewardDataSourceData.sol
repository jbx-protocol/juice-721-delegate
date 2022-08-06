// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';
import './JBNFTRewardTierData.sol';
import './../interfaces/IJBTieredLimitedNFTRewardDataSourceStore.sol';

/**
  @member directory The directory of terminals and controllers for projects.
  @member name The name of the token.
  @member symbol The symbol that the token should be represented by.
  @member tokenUriResolver A contract responsible for resolving the token URI for each token ID.
  @member contractUri A URI where contract metadata can be found. 
  @member owner The address that should own this contract.
  @member tierData The tier data according to which token distribution will be made. 
  @member reservedTokenBeneficiary The address receiving the reserved token
  @member store The store contract to use.
  @member lockReservedTokenChanges A flag indicating if reserved tokens can change over time by adding new tiers with a reserved rate.
  @member lockVotingUnitChanges A flag indicating if voting unit expectations can change over time by adding new tiers with voting units.
*/
struct JBDeployTieredNFTRewardDataSourceData {
  IJBDirectory directory;
  string name;
  string symbol;
  string baseUri;
  IJBTokenUriResolver tokenUriResolver;
  string contractUri;
  address owner;
  JBNFTRewardTierData[] tierData;
  address reservedTokenBeneficiary;
  IJBTieredLimitedNFTRewardDataSourceStore store;
  bool lockReservedTokenChanges;
  bool lockVotingUnitChanges;
}
