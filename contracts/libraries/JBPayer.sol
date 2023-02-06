// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@paulrberg/contracts/math/PRBMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplit.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';

library JBPayer {
  using SafeERC20 for IERC20;

  error TERMINAL_NOT_FOUND();
  error INCORRECT_DECIMAL_AMOUNT();

  event DistributeToSplit(
    JBSplit split,
    uint256 amount,
    address defaultBeneficiary,
    address caller
  );

  /** 
    @notice 
    Split an amount between all splits.

    @param _directory The directory of terminals and controllers for projects.
    @param _splits The splits.
    @param _token The token the amonut being split is in.
    @param _amount The amount of tokens being split, as a fixed point number. If the `_token` is ETH, this is ignored and msg.value is used in its place.
    @param _decimals The number of decimals in the `_amount` fixed point number. 
    @param _defaultBeneficiary The address that will benefit from any non-specified beneficiaries in splits.
    @param _projectId The ID of the project the splits are being made from.
  */
  function _payTo(
    IJBDirectory _directory,
    JBSplit[] memory _splits,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    address _defaultBeneficiary,
    uint256 _projectId
  ) internal {
    // Settle between all splits.
    for (uint256 i; i < _splits.length; ) {
      // Get a reference to the split being iterated on.
      JBSplit memory _split = _splits[i];

      // The amount to send towards the split.
      uint256 _splitAmount = PRBMath.mulDiv(
        _amount,
        _split.percent,
        JBConstants.SPLITS_TOTAL_PERCENT
      );

      if (_splitAmount > 0) {
        // Transfer tokens to the split.
        // If there's an allocator set, transfer to its `allocate` function.
        if (_split.allocator != IJBSplitAllocator(address(0))) {
          // Create the data to send to the allocator.
          JBSplitAllocationData memory _data = JBSplitAllocationData(
            _token,
            _splitAmount,
            _decimals,
            _projectId,
            0,
            _split
          );

          // Approve the `_amount` of tokens for the split allocator to transfer tokens from this contract.
          if (_token != JBTokens.ETH)
            IERC20(_token).safeApprove(address(_split.allocator), _splitAmount);

          // If the token is ETH, send it in msg.value.
          uint256 _payableValue = _token == JBTokens.ETH ? _splitAmount : 0;

          // Trigger the allocator's `allocate` function.
          try _split.allocator.allocate{value: _payableValue}(_data) {} catch {}

          // Otherwise, if a project is specified, make a payment to it.
        } else if (_split.projectId != 0) {
          // Send the projectId in the metadata.
          bytes memory _projectMetadata = new bytes(32);
          _projectMetadata = bytes(abi.encodePacked(_projectId));

          if (_split.preferAddToBalance)
            _addToBalanceOf(
              _directory,
              _split.projectId,
              _token,
              _splitAmount,
              _decimals,
              '',
              _projectMetadata
            );
          else
            _pay(
              _directory,
              _split.projectId,
              _token,
              _splitAmount,
              _decimals,
              _split.beneficiary != address(0) ? _split.beneficiary : _defaultBeneficiary,
              0,
              _split.preferClaimed,
              '',
              _projectMetadata
            );
        } else {
          // Transfer the ETH.
          if (_token == JBTokens.ETH)
            Address.sendValue(
              // Get a reference to the address receiving the tokens. If there's a beneficiary, send the funds directly to the beneficiary. Otherwise send to _defaultBeneficiary.
              _split.beneficiary != address(0) ? _split.beneficiary : payable(_defaultBeneficiary),
              _splitAmount
            );
            // Or, transfer the ERC20.
          else {
            IERC20(_token).safeTransfer(
              // Get a reference to the address receiving the tokens. If there's a beneficiary, send the funds directly to the beneficiary. Otherwise send to _defaultBeneficiary.
              _split.beneficiary != address(0) ? _split.beneficiary : _defaultBeneficiary,
              _splitAmount
            );
          }
        }
      }

      emit DistributeToSplit(_split, _splitAmount, _defaultBeneficiary, msg.sender);

      unchecked {
        ++i;
      }
    }
  }

  /** 
    @notice 
    Make a payment to the specified project.

    @param _directory The directory of terminals and controllers for projects.
    @param _projectId The ID of the project that is being paid.
    @param _token The token being paid in.
    @param _amount The amount of tokens being paid, as a fixed point number. 
    @param _decimals The number of decimals in the `_amount` fixed point number. 
    @param _beneficiary The address who will receive tokens from the payment.
    @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with 18 decimals.
    @param _preferClaimedTokens A flag indicating whether the request prefers to mint project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
    @param _memo A memo to pass along to the emitted event, and passed along the the funding cycle's data source and delegate.  A data source can alter the memo before emitting in the event and forwarding to the delegate.
    @param _metadata Bytes to send along to the data source and delegate, if provided.
  */
  function _pay(
    IJBDirectory _directory,
    uint256 _projectId,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string memory _memo,
    bytes memory _metadata
  ) internal {
    // Find the terminal for the specified project.
    IJBPaymentTerminal _terminal = _directory.primaryTerminalOf(_projectId, _token);

    // There must be a terminal.
    if (_terminal == IJBPaymentTerminal(address(0))) revert TERMINAL_NOT_FOUND();

    // The amount's decimals must match the terminal's expected decimals.
    if (_terminal.decimalsForToken(_token) != _decimals) revert INCORRECT_DECIMAL_AMOUNT();

    // Approve the `_amount` of tokens from the destination terminal to transfer tokens from this contract.
    if (_token != JBTokens.ETH) IERC20(_token).safeApprove(address(_terminal), _amount);

    // If the token is ETH, send it in msg.value.
    uint256 _payableValue = _token == JBTokens.ETH ? _amount : 0;

    // Send funds to the terminal.
    // If the token is ETH, send it in msg.value.
    try
      _terminal.pay{value: _payableValue}(
        _projectId,
        _amount, // ignored if the token is JBTokens.ETH.
        _token,
        _beneficiary,
        _minReturnedTokens,
        _preferClaimedTokens,
        _memo,
        _metadata
      )
    {} catch {}
  }

  /** 
    @notice 
    Add to the balance of the specified project.

    @param _directory The directory of terminals and controllers for projects.
    @param _projectId The ID of the project that is being paid.
    @param _token The token being paid in.
    @param _amount The amount of tokens being paid, as a fixed point number. If the token is ETH, this is ignored and msg.value is used in its place.
    @param _decimals The number of decimals in the `_amount` fixed point number. If the token is ETH, this is ignored and 18 is used in its place, which corresponds to the amount of decimals expected in msg.value.
    @param _memo A memo to pass along to the emitted event.
    @param _metadata Extra data to pass along to the terminal.
  */
  function _addToBalanceOf(
    IJBDirectory _directory,
    uint256 _projectId,
    address _token,
    uint256 _amount,
    uint256 _decimals,
    string memory _memo,
    bytes memory _metadata
  ) internal {
    // Find the terminal for the specified project.
    IJBPaymentTerminal _terminal = _directory.primaryTerminalOf(_projectId, _token);

    // There must be a terminal.
    if (_terminal == IJBPaymentTerminal(address(0))) revert TERMINAL_NOT_FOUND();

    // The amount's decimals must match the terminal's expected decimals.
    if (_terminal.decimalsForToken(_token) != _decimals) revert INCORRECT_DECIMAL_AMOUNT();

    // Approve the `_amount` of tokens from the destination terminal to transfer tokens from this contract.
    if (_token != JBTokens.ETH) IERC20(_token).safeApprove(address(_terminal), _amount);

    // If the token is ETH, send it in msg.value.
    uint256 _payableValue = _token == JBTokens.ETH ? _amount : 0;

    // Add to balance so tokens don't get issued.
    try
      _terminal.addToBalanceOf{value: _payableValue}(_projectId, _amount, _token, _memo, _metadata)
    {} catch {}
  }
}
