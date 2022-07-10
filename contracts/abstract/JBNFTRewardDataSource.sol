// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPayDelegate.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBPayParamsData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBTokenAmount.sol';
import {ERC721 as ERC721Rari} from '@rari-capital/solmate/src/tokens/ERC721.sol';
import '../interfaces/IJBNFTRewardDataSource.sol';
import '../interfaces/ITokenSupplyDetails.sol';

/**
  @title 
  JBNFTRewardDataSource

  @notice 
  Data source that offers project contributors NFTs.

  @dev 
  This JBFundingCycleDataSource implementation will simply through the weight, reclaimAmount, and memos they are called with.

  @dev
  Adheres to -
  IJBNFTRewardDataSource: General interface for the methods in this contract that interact with the blockchain's state according to the protocol's rules.
  IJBFundingCycleDataSource: Allows this contract to be attached to a funding cycle to have its methods called during regular protocol operations.
  IJBPayDelegate: Allows this contract to receive callbacks when a project receives a payment.

  @dev
  Inherits from -
  todo
  ERC721Votes: A checkpointable standard definition for non-fungible tokens (NFTs).
  Ownable: Includes convenience functionality for checking a message sender's permissions before executing certain transactions.
*/
abstract contract JBNFTRewardDataSource is
  IJBNFTRewardDataSource,
  IJBFundingCycleDataSource,
  IJBPayDelegate,
  ERC721Rari,
  Ownable
{
  using Strings for uint256;

  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INVALID_PAYMENT_EVENT();

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /**
    @notice
    The ID of the project this NFT should be distributed for.
  */
  uint256 public immutable override projectId;

  /**
    @notice
    The directory of terminals and controllers for projects.
  */
  IJBDirectory public immutable override directory;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /**
    @notice
    Custom token URI resolver, superceeds base URI.
  */
  IJBTokenUriResolver public override tokenUriResolver;

  /**
    @notice
    The base URI to use for tokens if a URI resolver isn't provided. 

    @dev 
    The token ID will be concatenated onto the base URI to form the token URI.
  */
  string public override baseUri;

  /**
    @notice
    Contract metadata uri.
  */
  string public override contractUri;

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /**
    @notice
    Indicates if this contract adheres to the specified interface.

    @dev 
    See {IERC165-supportsInterface}.

    @param _interfaceId The ID of the interface to check for adherance to.
  */
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(ERC721Rari, IERC165)
    returns (bool)
  {
    return
      _interfaceId == type(IJBNFTRewardDataSource).interfaceId ||
      _interfaceId == type(IJBFundingCycleDataSource).interfaceId ||
      super.supportsInterface(_interfaceId); // check with rari-ERC721
  }

  /**
    @notice 
    Returns the URI where the ERC-721 standard JSON of a token is hosted.

    @param _tokenId The ID of the token to get a URI of.

    @return The token URI to use for the provided `_tokenId`.
  */
  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    // A token without an owner doesn't have a URI.
    if (_ownerOf[_tokenId] == address(0)) return '';

    // If a token URI resolver is provided, use it to resolve the token URI.
    if (address(tokenUriResolver) != address(0)) return tokenUriResolver.getUri(_tokenId);

    // Append the token ID to the base URI.
    return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, _tokenId.toString())) : '';
  }

  /**
    @notice 
    Part of IJBFundingCycleDataSource, this function gets called when the project receives a payment. It will set itself as the delegate to get a callback from the terminal.

    @dev 
    This function will revert if the contract calling it is not the store of one of the project's terminals. 

    @param _data The Juicebox standard project contribution data.

    @return weight The weight that tokens should get minted in accordance to 
    @return memo The memo that should be forwarded to the event.
    @return delegate A delegate to call once the payment has taken place.
  */
  function payParams(JBPayParamsData calldata _data)
    external
    view
    override
    returns (
      uint256 weight,
      string memory memo,
      IJBPayDelegate delegate
    )
  {
    // Forward the recieved weight and memo, and use this contract as a pay delegate.
    return (_data.weight, _data.memo, IJBPayDelegate(address(this)));
  }

  /**
    @notice 
    Part of IJBFundingCycleDataSource, this function gets called when a project's token holders redeem. It will return the standard properties.

    @param _data The Juicebox standard project redemption data.

    @return reclaimAmount The amount that should be reclaimed from the treasury.
    @return memo The memo that should be forwarded to the event.
    @return delegate A delegate to call once the redemption has taken place.
  */
  function redeemParams(JBRedeemParamsData calldata _data)
    external
    pure
    override
    returns (
      uint256 reclaimAmount,
      string memory memo,
      IJBRedemptionDelegate delegate
    )
  {
    // Return the default values.
    return (_data.reclaimAmount.value, _data.memo, IJBRedemptionDelegate(address(0)));
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projectId The ID of the project for which this NFT should be minted in response to payments made. 
    @param _directory The directory of terminals and controllers for projects.
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _baseUri The token's base URI, to be used if a URI resolver is not provided. 
    @param _contractUri A URI where contract metadata can be found. 
    @param _owner The address that will own this contract.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _baseUri,
    string memory _contractUri,
    address _owner
  ) ERC721Rari(_name, _symbol) {
    projectId = _projectId;
    directory = _directory;
    baseUri = _baseUri;
    tokenUriResolver = _tokenUriResolver;
    contractUri = _contractUri;

    // Transfer the ownership to the specified address.
    if (_owner != address(0)) _transferOwnership(_owner);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /**
    @notice 
    Part of IJBPayDelegate, this function gets called when the project receives a payment. It will mint an NFT to the contributor (_data.beneficiary) if conditions are met.

    @dev 
    This function will revert if the contract calling is not one of the project's terminals. 

    @param _data The Juicebox standard project contribution data.
  */
  function didPay(JBDidPayData calldata _data) external override {
    // Make sure the caller is a terminal of the project, and the call is being made on behalf of an interaction with the correct project.
    if (
      !(directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))) ||
      _data.projectId != projectId
    ) revert INVALID_PAYMENT_EVENT();

    // Process the contribution.
    _processContribution(_data);
  }

  /**
    @notice
    Set a contract metadata uri to contain opensea-style metadata.

    @dev
    Only the contract's owner can set the contract URI.

    @param _contractUri The new contract URI.
  */
  function setContractUri(string calldata _contractUri) external override onlyOwner {
    // Store the new value.
    contractUri = _contractUri;

    emit SetContractUri(_contractUri, msg.sender);
  }

  /**
    @notice
    Set a base token URI.

    @dev
    Only the contract's owner can set the base URI.

    @param _baseUri The new base URI.
  */
  function setBaseUri(string calldata _baseUri) external override onlyOwner {
    // Store the new value.
    baseUri = _baseUri;

    emit SetBaseUri(_baseUri, msg.sender);
  }

  /**
    @notice
    Set a token URI resolver.

    @dev
    Only the contract's owner can set the token URI resolver.

    @param _tokenUriResolver The new base URI.
  */
  function setTokenUriResolver(IJBTokenUriResolver _tokenUriResolver) external override onlyOwner {
    // Store the new value.
    tokenUriResolver = _tokenUriResolver;

    emit SetTokenUriResolver(_tokenUriResolver, msg.sender);
  }

  //*********************************************************************//
  // ---------------------- internal transactions ---------------------- //
  //*********************************************************************//

  function _processContribution(JBDidPayData calldata _data) internal virtual;
}
