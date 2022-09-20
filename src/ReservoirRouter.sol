pragma solidity 0.8.17;

import { IWETH } from "src/interfaces/IWETH.sol";
import { IReservoirRouter } from "src/interfaces/IReservoirRouter.sol";
import { IGenericFactory } from "src/interfaces/IGenericFactory.sol";
import { Multicall } from "src/abstract/Multicall.sol";

contract ReservoirRouter is IReservoirRouter, Multicall{
    IGenericFactory public factory;
    IWETH public WETH;

    constructor (address aFactory, address aWETH) {
        factory = IGenericFactory(aFactory);
        WETH = IWETH(aWETH);
    }

    function addLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 liquidity) {}
    function removeLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 amount0, uint256 amount1) {}

    function swapExactForVariable(address pair, address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {}
    function swapVariableForExact(address pair, address tokenOut, uint256 amountOut, uint256 maxAmountIn) external returns (uint256 amountIn) {}

    function getAmountOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view {}
    function getAmountIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view {}
    function quoteAddLiquidity(address pair, uint256 amount0, uint256 amount1) external view {}
    function quoteRemoveLiquidity(address pair, uint256 lpTokenAmount) external view {}
}
