// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import { IMulticall } from "src/interfaces/IMulticall.sol";

/// @notice Helper utility that enables calling multiple local methods in a single call.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
/// License-Identifier: GPL-2.0-or-later
abstract contract Multicall is IMulticall {
    function multicall(bytes[] calldata aData) external payable returns (bytes[] memory rResults) {
        rResults = new bytes[](aData.length);

        for (uint256 i; i < aData.length;) {
            (bool lSuccess, bytes memory lResult) = address(this).delegatecall(aData[i]);

            if (!lSuccess) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (lResult.length < 68) revert();
                assembly {
                    lResult := add(lResult, 0x04)
                }
                revert(abi.decode(lResult, (string)));
            }

            rResults[i] = lResult;

        // cannot realistically overflow on human timescales
        unchecked {
            ++i;
        }
        }
    }
}
