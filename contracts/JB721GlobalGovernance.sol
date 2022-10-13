// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import './JBTiered721Delegate.sol';
import './interfaces/IJB721TieredGovernance.sol';

contract JB721GlobalGovernance is Votes, JBTiered721Delegate {

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _account The account to get voting units for.

    @return units The voting units for the account.
  */
  function _getVotingUnits(address _account)
    internal
    view
    virtual
    override
    returns (uint256 units)
  {
    return store.votingUnitsOf(address(this), _account);
  }

  /**
   @notice
   handles the tier voting accounting

    @param _from The account to transfer voting units from.
    @param _to The account to transfer voting units to.
    @param _tokenId The id of the token for which voting units are being transfered.
    @param _tier The tier the token id is part of
   */
  function _afterTokenTransferAccounting(
    address _from,
    address _to,
    uint256 _tokenId,
    JB721Tier memory _tier
  ) internal virtual override {
    if (_tier.votingUnits != 0) {
      // Transfer the voting units.
      _transferVotingUnits(_from, _to, _tier.votingUnits);
    }
  }
}
