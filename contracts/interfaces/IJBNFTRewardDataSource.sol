// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';

interface IJBNFTRewardDataSource {
  event SetContractUri(string indexed contractUri, address caller);

  event SetBaseUri(string indexed baseUri, address caller);

  event SetTokenUriResolver(IJBTokenUriResolver indexed newResolver, address caller);

  function projectId() external view returns (uint256);

  function directory() external view returns (IJBDirectory);

  function contractUri() external view returns (string memory);

  function tokenUriResolver() external view returns (IJBTokenUriResolver);

  function firstOwnerOf(uint256 _tokenId) external view returns (address);

  function setContractUri(string calldata _contractMetadataUri) external;

  function setTokenUriResolver(IJBTokenUriResolver _tokenUriResolverAddress) external;
}
