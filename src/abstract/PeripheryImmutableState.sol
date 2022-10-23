// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.13;

import { IPeripheryImmutableState } from "src/interfaces/IPeripheryImmutableState.sol";
import { GenericFactory } from "v3-core/src/GenericFactory.sol";
import { IWETH } from "src/interfaces/IWETH.sol";

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    /// @inheritdoc IPeripheryImmutableState
    GenericFactory public immutable override factory;
    /// @inheritdoc IPeripheryImmutableState
    IWETH public immutable override WETH; // solhint-disable-line var-name-mixedcase

    constructor(address aFactory, address aWETH) {
        factory = GenericFactory(aFactory);
        WETH = IWETH(aWETH);
    }
}
