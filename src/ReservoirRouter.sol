pragma solidity 0.8.13;

import { IReservoirRouter } from "src/interfaces/IReservoirRouter.sol";

import { PeripheryImmutableState } from "src/abstract/PeripheryImmutableState.sol";
import { PeripheryPayments } from "src/abstract/PeripheryPayments.sol";
import { DeadlineCheck } from "src/abstract/DeadlineCheck.sol";
import { Multicall } from "src/abstract/Multicall.sol";

contract ReservoirRouter is
    IReservoirRouter,
    PeripheryImmutableState,
    PeripheryPayments,
    DeadlineCheck,
    Multicall
{
    constructor (address aFactory, address aWETH) PeripheryImmutableState(aFactory, aWETH) {}

    function addLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 liquidity) {}
    function removeLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 amount0, uint256 amount1) {}

    function swapExactForVariable(address pair, address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {}
    function swapVariableForExact(address pair, address tokenOut, uint256 amountOut, uint256 maxAmountIn) external returns (uint256 amountIn) {}

    function getAmountOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut) {}
    function getAmountsOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view returns(uint256[] memory amountsOut) {}

    function getAmountIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256 amountIn) {}
    function getAmountsIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountOut) external view returns(uint256[] memory amountsIn) {}

    function quoteAddLiquidity(address pair, uint256 amount0, uint256 amount1) external view {}
    function quoteRemoveLiquidity(address pair, uint256 lpTokenAmount) external view {}
}
