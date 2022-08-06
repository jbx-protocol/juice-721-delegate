// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';

interface IJBNFTRewardDataSource {
  event SetBaseUri(string indexed baseUri, address caller);

  event SetContractUri(string indexed contractUri, address caller);

  event SetTokenUriResolver(IJBTokenUriResolver indexed newResolver, address caller);

  function projectId() external view returns (uint256);

  function directory() external view returns (IJBDirectory);

  function setBaseUri(string memory _baseUri) external;

  function setContractUri(string calldata _contractMetadataUri) external;

  function setTokenUriResolver(IJBTokenUriResolver _tokenUriResolverAddress) external;
}
