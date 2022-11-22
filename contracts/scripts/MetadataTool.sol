// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import 'forge-std/Script.sol';

contract MetadataTool is Script {
  
  function decode(bytes memory _metadata) external {

    (, , , bool _dontMint, bool _expectMintFromExtraFunds, bool _dontOverspend, uint16[] memory _tierIdsToMint) = abi.decode(
        _metadata,
        (bytes32, bytes32, bytes4, bool, bool, bool, uint16[])
      );
    
    console.log("dontMint: ", _dontMint);
    console.log("expectMintFromExtraFunds: ", _expectMintFromExtraFunds);
    console.log("dontOverspend: ", _dontOverspend);

    if(_tierIdsToMint.length == 0) console.log("No tier ids passed");
    
    for(uint256 i; i < _tierIdsToMint.length; i++)
      console.log("_tierIdsToMint: idx ",i, " tier id: ", _tierIdsToMint[i]);
  }
}
