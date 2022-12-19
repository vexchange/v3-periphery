pragma solidity ^0.8.0;

interface IReservoirRouter {
    /*//////////////////////////////////////////////////////////////////////////
                                LIQUIDITY METHODS
    //////////////////////////////////////////////////////////////////////////*/

    function addLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aAmountADesired,
        uint256 aAmountBDesired,
        uint256 aAmountAMin,
        uint256 aAmountBMin,
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
    ) external payable returns (uint256 rAmountOut);

    function swapVariableForExact(
        uint256 aAmountOut,
        uint256 aAmountInMax,
        address[] calldata aPath,
        uint256[] calldata aCurveIds,
        address aTo
    ) external payable returns (uint256[] memory rAmounts);
}
