pragma solidity 0.8.17;

import { IGenericFactory } from "src/interfaces/IGenericFactory.sol";

interface IReservoirRouter {

    function factory() external pure returns (IGenericFactory);
    // do we want this name or do we want a more generic WNATIVE
    function WETH() external pure returns (address);

    /*//////////////////////////////////////////////////////////////////////////
                                LIQUIDITY METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function addLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 liquidity);
    function removeLiquidity(address pair, uint256 amount0In, uint256 amount1In) external returns (uint256 amount0, uint256 amount1);

    // the implementation these two functions take a lower priority
    // will implement when we have the time, and does not block merge
    function addLiquiditySingle(address pair, address token, uint256 amountIn) external returns (uint256 liquidity);
    function removeLiquiditySingle(address pair, address token, uint256 lpTokenAmount) external returns (uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                SWAP METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function swapExactForVariable(address pair, address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
    function swapVariableForExact(address pair, address tokenOut, uint256 amountOut, uint256 maxAmountIn) external returns (uint256 amountIn);

    /*//////////////////////////////////////////////////////////////////////////
                                QUERY METHODS (VIEW)
    //////////////////////////////////////////////////////////////////////////*/

    function getAmountOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view;
    function getAmountIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view;
    function quoteAddLiquidity(address pair, uint256 amount0, uint256 amount1) external view;
    function quoteRemoveLiquidity(address pair, uint256 lpTokenAmount) external view;
}
