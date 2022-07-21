// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';
import './JBNFTRewardTierData.sol';

/**
  @member directory The directory of terminals and controllers for projects.
  @member name The name of the token.
  @member symbol The symbol that the token should be represented by.
  @member tokenUriResolver A contract responsible for resolving the token URI for each token ID.
  @member contractUri A URI where contract metadata can be found. 
  @member owner The address that should own this contract.
  @member tierData The tier data according to which token distribution will be made. 
  @member shouldMintByDefault A flag indicating if contributions should mint NFTs if a tier's treshold is passed even if the tier ID isn't specified. 
  @member reservedTokenBeneficiary The address receiving the reserved token
*/
struct JBDeployTieredNFTRewardDataSourceData {
  IJBDirectory directory;
  string name;
  string symbol;
  IJBTokenUriResolver tokenUriResolver;
  string contractUri;
  string baseUri;
  address owner;
  JBNFTRewardTierData[] tierData;
  bool shouldMintByDefault;
  address reservedTokenBeneficiary;
}
