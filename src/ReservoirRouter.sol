pragma solidity 0.8.13;

import { IReservoirRouter } from "src/interfaces/IReservoirRouter.sol";
import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";
import { TransferHelper } from "src/libraries/TransferHelper.sol";

import { PeripheryImmutableState } from "src/abstract/PeripheryImmutableState.sol";
import { PeripheryPayments } from "src/abstract/PeripheryPayments.sol";
import { DeadlineCheck } from "src/abstract/DeadlineCheck.sol";
import { Multicall } from "src/abstract/Multicall.sol";

import "forge-std/console.sol";

contract ReservoirRouter is
    IReservoirRouter,
    PeripheryImmutableState,
    PeripheryPayments,
    DeadlineCheck,
    Multicall
{
    constructor (address aFactory, address aWETH) PeripheryImmutableState(aFactory, aWETH) {}

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint curveId,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private returns (uint amountA, uint amountB) {
        if (factory.getPair(tokenA, tokenB, curveId) == address(0)) {
            factory.createPair(tokenA, tokenB, curveId);
        }

        (uint256 reserveA, uint256 reserveB) = ReservoirLibrary.getReserves(factory, tokenA, tokenB, curveId);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        }
        else {
            uint amountBOptimal = ReservoirLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "ReservoirRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = ReservoirLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "ReservoirRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external payable returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, curveId, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pair = factory.getPair(tokenA, tokenB, curveId);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = IReservoirPair(pair).mint(to);
    }

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
