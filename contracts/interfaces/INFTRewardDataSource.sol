// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './IToken721UriResolver.sol';
import './ITokenSupplyDetails.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';

interface INFTRewardDataSource is ITokenSupplyDetails {
  event SetContractUri(string indexed contractUri, address caller);

  event SetBaseUri(string indexed baseUri, address caller);

  event SetTokenUriResolver(IToken721UriResolver indexed tokenUriResolver, address caller);

  function projectId() external view returns (uint256);

  function directory() external view returns (IJBDirectory);

  function baseUri() external view returns (string memory);

  function contractUri() external view returns (string memory);

  function tokenUriResolver() external view returns (IToken721UriResolver);

  function setContractUri(string calldata _contractMetadataUri) external;

  function setTokenUriResolver(IToken721UriResolver _tokenUriResolverAddress) external;

  function setBaseUri(string calldata _baseUri) external;
}
