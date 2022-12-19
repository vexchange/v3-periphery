// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";

import "src/interfaces/IPeripheryPayments.sol";
import "src/interfaces/IWETH.sol";

import "src/libraries/TransferHelper.sol";

import "src/abstract/PeripheryImmutableState.sol";

abstract contract PeripheryPayments is IPeripheryPayments, PeripheryImmutableState {
    receive() external payable {
        require(msg.sender == address(WETH), "PP: NOT_WETH");
    }

    /// @inheritdoc IPeripheryPayments
    function unwrapWETH(uint256 aAmountMinimum, address aRecipient) public payable override {
        uint256 lBalanceWETH = IWETH(WETH).balanceOf(address(this));
        require(lBalanceWETH >= aAmountMinimum, "PP: INSUFFICIENT_WETH");

        if (lBalanceWETH > 0) {
            IWETH(WETH).withdraw(lBalanceWETH);
            TransferHelper.safeTransferETH(aRecipient, lBalanceWETH);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function sweepToken(address aToken, uint256 aAmountMinimum, address aRecipient) public payable override {
        uint256 lBalanceToken = IERC20(aToken).balanceOf(address(this));
        require(lBalanceToken >= aAmountMinimum, "PP: INSUFFICIENT_TOKEN");

        if (lBalanceToken > 0) {
            TransferHelper.safeTransfer(aToken, aRecipient, lBalanceToken);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function refundETH() external payable override {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    /// @param aToken The token to pay
    /// @param aPayer The entity that must pay
    /// @param aRecipient The entity that will receive payment
    /// @param aValue The amount to pay
    function _pay(address aToken, address aPayer, address aRecipient, uint256 aValue) internal {
        if (aToken == address(WETH) && address(this).balance >= aValue) {
            // pay with WETH
            IWETH(WETH).deposit{value: aValue}(); // wrap only what is needed to pay
            IWETH(WETH).transfer(aRecipient, aValue);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(aToken, aPayer, aRecipient, aValue);
        }
    }
}
