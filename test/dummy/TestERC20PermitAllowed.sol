pragma solidity ^0.8.0;

import { ERC20Permit, ERC20 } from "@openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import { IERC20PermitAllowed } from "src/interfaces/IERC20PermitAllowed.sol";

/// @dev this class exposes the EIP-2612 type of permit function as well as the "allowed" type of permit function
/// to facilitate testing with just one class instead of having two distinct ones
/// the permit with expired and allow just uses the EIP2616 type hash, just for testing purposes
contract TestERC20PermitAllowed is ERC20Permit, IERC20PermitAllowed {
    constructor(uint256 aAmountToMint) ERC20("Test ERC20", "TEST") ERC20Permit("Test ERC20") {
        _mint(msg.sender, aAmountToMint);
    }

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(this.nonces(holder) == nonce, "TestERC20PermitAllowed::permit: wrong nonce");
        permit(holder, spender, allowed ? type(uint256).max : 0, expiry, v, r, s);
    }
}
