pragma solidity ^0.8.0;

struct ExtraData {
    uint64 token0PrecisionMultiplier;
    uint64 token1PrecisionMultiplier;
    uint64 amplificationCoefficient;
}

interface IQuoter {

    /*//////////////////////////////////////////////////////////////////////////
                                QUERY METHODS (VIEW)
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev aExtraData for StablePair use, to leave blank for ConstantProductPair
    function getAmountOut(
        uint256 aAmountIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns(uint256 rAmountOut);

    /// @dev aExtraData for StablePair use, to leave blank for ConstantProductPair
    function getAmountIn(
        uint256 aAmountOut,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns(uint256 rAmountIn);

    /// @dev aPath array of ERC20 tokens to swap into
    function getAmountsOut(
        uint256 aAmountIn,
        address[] calldata aPath,
        uint256[] calldata aCurveIds
    ) external view returns(uint256[] memory rAmountsOut);

    /// @dev aPath array of ERC20 tokens to swap into
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
