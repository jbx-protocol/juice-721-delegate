// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
  @notice
  Utilities to manage bool bitmap storing the inactive tiers.
*/
library JBBitmap {

  /**
    @notice Struct storing the word at a given depth in the bitmap.
            A given 
  */
  struct BitmapWord {
      uint256 _currentWord;
      uint256 _currentDepth;
  }

  /**
    @notice
    initialise a BitmapWord struct, based on the mapping storage pointer and a given index
  */
  function readId(mapping(uint256=>uint256) storage self, uint256 _index) internal view returns(BitmapWord memory) {
      uint256 _depth = _retrieveDepth(_index);

      return BitmapWord({
          _currentWord: self[_depth],
          _currentDepth: _depth
      });
  }

  /**
    @notice
    Returns the status of a given bit, in the single word stored in a BitmapWord struct
  */
  function isTierIdRemoved(BitmapWord memory self, uint256 _index) internal pure returns(bool){
      return (self._currentWord >> (_index % 256) ) & 1 == 1;
  }

  /**
    @notice
    Returns the status of a bit in a given bitmap (index is the index in the reshaped bitmap matrix 1*n)
  */
  function isTierIdRemoved(mapping(uint256=>uint256) storage self, uint256 _index) internal view returns(bool) {
      uint256 _depth = _retrieveDepth(_index);
      return isTierIdRemoved(BitmapWord({ _currentWord: self[_depth], _currentDepth: _depth}), _index);
  }

  /**
    @notice
    Flip the bit at a given index to true (this is a one-way operation)
  */
  function removeTier(mapping(uint256=>uint256) storage self, uint256 _index) internal {
      uint256 _depth = _retrieveDepth(_index);
      self[_depth] |= uint256(1 << (_index % 256));
  }

  /**
    @notice
    Return true if the index is in an another word than the one stored in the BitmapWord struct
  */
  function refreshBitmapNeeded(BitmapWord memory self, uint256 _index) internal pure returns(bool) {
      return _retrieveDepth(_index) != self._currentDepth;
  }

  // Lib internal
  
  /**
    @notice
    Return the lines of the bitmap matrix where an index lies
  */
  function _retrieveDepth(uint256 _index) internal pure returns(uint256) {
      return _index / 256;
  }
}
