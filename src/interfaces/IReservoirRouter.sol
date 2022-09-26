pragma solidity 0.8.13;

struct ExtraData {
    uint64 token0PrecisionMultiplier;
    uint64 token1PrecisionMultiplier;
    uint64 amplificationCoefficient;
}

interface IReservoirRouter {

    /*//////////////////////////////////////////////////////////////////////////
                                LIQUIDITY METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external payable returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB);

    // the implementation these two functions take a lower priority
    // will implement when we have the time, and does not block merge
    // function addLiquiditySingle(address pair, address token, uint256 amountIn) external returns (uint256 liquidity);
    // function removeLiquiditySingle(address pair, address token, uint256 lpTokenAmount) external returns (uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                SWAP METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function swapExactForVariable(address pair, address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
    function swapVariableForExact(address pair, address tokenOut, uint256 amountOut, uint256 maxAmountIn) external returns (uint256 amountIn);

    /*//////////////////////////////////////////////////////////////////////////
                                QUERY METHODS (VIEW)
    //////////////////////////////////////////////////////////////////////////*/

    /**

    @param extraData for StablePair use, to leave blank for ConstantProductPair. See ReservoirLibrary

     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 curveId, uint256 swapFee, ExtraData calldata extraData) external pure returns(uint256 amountOut);
    function getAmountsOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view returns(uint256[] memory amountsOut);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 curveId, uint256 swapFee, ExtraData calldata extraData) external pure returns(uint256 amountIn);
    function getAmountsIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountOut) external view returns(uint256[] memory amountsIn);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);
}
