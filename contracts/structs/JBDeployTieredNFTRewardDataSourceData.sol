// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';
import './JBNFTRewardTier.sol';

/**
  @member directory The directory of terminals and controllers for projects.
  @member name The name of the token.
  @member symbol The symbol that the token should be represented by.
  @member tokenUriResolver A contract responsible for resolving the token URI for each token ID.
  @member baseUri The token's base URI, to be used if a URI resolver is not provided. 
  @member contractUri A URI where contract metadata can be found. 
  @member owner The address that should own this contract.
  @member contributionToken The token that contributions are expected to be in terms of.
  @member tiers The tiers according to which token distribution will be made. 
  @member shouldMintByDefault A flag indicating if contributions should mint NFTs if a tier's treshold is passed even if the tier ID isn't specified. 
*/
struct JBDeployTieredNFTRewardDataSourceData {
  IJBDirectory directory;
  string name;
  string symbol;
  IJBTokenUriResolver tokenUriResolver;
  string baseUri;
  string contractUri;
  address owner;
  address contributionToken;
  JBNFTRewardTier[] tiers;
  bool shouldMintByDefault;
}
