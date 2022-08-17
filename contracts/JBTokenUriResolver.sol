// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBTokenUriResolver.sol';

contract JBTokenUriResolver is IJBTokenUriResolver {
  mapping(uint256 => string) internal _tokenUri;

  string internal _generic;

  function getUri(uint256 _projectId) external view override returns (string memory tokenUri) {
    if (keccak256(bytes(_tokenUri[_projectId])) != keccak256(new bytes(0)))
      return _tokenUri[_projectId];

    return _generic;
  }

  function setUri(uint256 _projectId, string calldata _uri) external {
    _tokenUri[_projectId] = _uri;
  }

  function setGeneric(string calldata _uri) external {
    _generic = _uri;
  }
}
