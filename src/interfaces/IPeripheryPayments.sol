// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Periphery Payments
/// @notice Functions to ease deposits and withdrawals of ETH
interface IPeripheryPayments {
    /// @notice Unwraps the contract's WETH balance and sends it to aRecipient as ETH.
    /// @dev The aAmountMinimum parameter prevents malicious contracts from stealing WETH from users.
    /// @param aAmountMinimum The minimum amount of WETH to unwrap
    /// @param aRecipient The address receiving ETH
    function unwrapWETH(uint256 aAmountMinimum, address aRecipient) external payable;

    /// @notice Refunds any ETH balance held by this contract to the `msg.sender`
    /// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
    /// that use ether for the input amount
    function refundETH() external payable;

    /// @notice Transfers the full amount of a token held by this contract to aRecipient
    /// @dev The aAmountMinimum parameter prevents malicious contracts from stealing the token from users
    /// @param aToken The contract address of the aToken which will be transferred to `aRecipient`
    /// @param aAmountMinimum The minimum amount of aToken required for a transfer
    /// @param aRecipient The destination address of the aToken
    function sweepToken(address aToken, uint256 aAmountMinimum, address aRecipient) external payable;
}
