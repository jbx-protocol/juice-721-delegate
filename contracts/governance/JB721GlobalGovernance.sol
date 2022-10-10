// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '../JBTiered721Delegate.sol';
import '../interfaces/IJB721TieredGovernance.sol';

contract JB721GlobalGovernance is Votes, JBTiered721Delegate {
  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projectId The ID of the project this contract's functionality applies to.
    @param _directory The directory of terminals and controllers for projects.
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _fundingCycleStore A contract storing all funding cycle configurations.
    @param _baseUri A URI to use as a base for full token URIs.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _pricing The tier pricing according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _store A contract that stores the NFT's data.
    @param _flags A set of flags that help define how this contract works.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBFundingCycleStore _fundingCycleStore,
    string memory _baseUri,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    JB721PricingParams memory _pricing,
    IJBTiered721DelegateStore _store,
    JBTiered721Flags memory _flags
  )
    JBTiered721Delegate(
      _projectId,
      _directory,
      _name,
      _symbol,
      _fundingCycleStore,
      _baseUri,
      _tokenUriResolver,
      _contractUri,
      _pricing,
      _store,
      _flags
    )
    // Replacing this with `_name` is stack-too-deep, however setting name first
    // and then using the getter method does not ¯\_(ツ)_/¯
    EIP712(name(), '1')
  {}

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
