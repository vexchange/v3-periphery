// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.13;

import { IPeripheryImmutableState } from "src/interfaces/IPeripheryImmutableState.sol";
import { IGenericFactory } from "v3-core/src/interfaces/IGenericFactory.sol";
import { IWETH } from "src/interfaces/IWETH.sol";

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    /// @inheritdoc IPeripheryImmutableState
    IGenericFactory public immutable override factory;
    /// @inheritdoc IPeripheryImmutableState
    IWETH public immutable override WETH;

    constructor(address _factory, address _WETH) {
        factory = IGenericFactory(_factory);
        WETH = IWETH(_WETH);
    }
}
