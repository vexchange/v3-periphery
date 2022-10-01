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
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint aAmountADesired,
        uint aAmountBDesired,
        uint aAmountAMin,
        uint aAmountBMin,
        address aTo
    ) external payable returns (uint256 rAmountA, uint256 rAmountB, uint256 rLiq);

    function removeLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aLiq,
        uint256 aAmountAMin,
        uint256 aAmountBMin,
        address aTo
    ) external payable returns (uint256 rAmountA, uint256 rAmountB);

    /*//////////////////////////////////////////////////////////////////////////
                                SWAP METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function swapExactForVariable(
        uint256 aAmountIn,
        uint256 aAmountOutMin,
        address[] calldata aPath,
        uint256[] calldata aCurveIds,
        address aTo
    ) external payable returns (uint256[] memory rAmounts);

    function swapVariableForExact(
        uint256 aAmountOut,
        uint256 aAmountInMax,
        address[] calldata aPath,
        uint256[] calldata aCurveIds,
        address aTo
    ) external payable returns (uint256[] memory rAmounts);

    /*//////////////////////////////////////////////////////////////////////////
                                QUERY METHODS (VIEW)
    //////////////////////////////////////////////////////////////////////////*/

    /// @param aExtraData for StablePair use, to leave blank for ConstantProductPair. See ReservoirLibrary
    function getAmountOut(
        uint256 aAmountIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns(uint256 rAmountOut);

    /// @param aExtraData for StablePair use, to leave blank for ConstantProductPair. See ReservoirLibrary
    function getAmountIn(
        uint256 aAmountOut,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns(uint256 rAmountIn);

    /// @param aPath array of ERC20 tokens to swap into
    function getAmountsOut(
        uint256 aAmountIn,
        address[] calldata aPath,
        uint256[] calldata aCurveIds
    ) external view returns(uint256[] memory rAmountsOut);

    /// @param aPath array of ERC20 tokens to swap into
    function getAmountsIn(
        uint256 aAmountOut,
        address[] calldata aPath,
        uint256[] calldata aCurveIds
    ) external view returns(uint256[] memory rAmountsIn);

    function quoteAddLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aAmountADesired,
        uint256 aAmountBDesired
    ) external view returns (uint256 rAmountA, uint256 rAmountB, uint256 rLiq);

    function quoteRemoveLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aLiq
    ) external view returns (uint256 rAmountA, uint256 rAmountB);
}
