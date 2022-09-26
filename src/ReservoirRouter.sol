pragma solidity 0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";

import { IReservoirRouter } from "src/interfaces/IReservoirRouter.sol";
import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";
import { StablePair } from "v3-core/src/curve/stable/StablePair.sol";

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";
import { TransferHelper } from "src/libraries/TransferHelper.sol";

import { PeripheryImmutableState } from "src/abstract/PeripheryImmutableState.sol";
import { PeripheryPayments } from "src/abstract/PeripheryPayments.sol";
import { PredicateHelper } from "src/abstract/PredicateHelper.sol";
import { Multicall } from "src/abstract/Multicall.sol";

contract ReservoirRouter is
    IReservoirRouter,
    PeripheryImmutableState,
    PeripheryPayments,
    PredicateHelper,
    Multicall
{
    uint256 constant MINIMUM_LIQUIDITY = 1e3;

    constructor (address aFactory, address aWETH) PeripheryImmutableState(aFactory, aWETH) {}

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint curveId,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private returns (uint amountA, uint amountB, address pair) {
        pair = factory.getPair(tokenA, tokenB, curveId);

        if (pair == address(0)) {
            pair = factory.createPair(tokenA, tokenB, curveId);
        }

        (uint256 reserveA, uint256 reserveB) = ReservoirLibrary.getReserves(address(factory), tokenA, tokenB, curveId);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        }
        else {
            uint amountBOptimal = ReservoirLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "RR: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = ReservoirLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "RR: INSUFFICIENT_A_AMOUNT");
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
        address pair;
        (amountA, amountB, pair) = _addLiquidity(tokenA, tokenB, curveId, amountADesired, amountBDesired, amountAMin, amountBMin);

        _pay(tokenA, msg.sender, pair, amountA);
        _pay(tokenB, msg.sender, pair, amountB);

        liquidity = IReservoirPair(pair).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external /*payable*/ returns (uint256 amountA, uint256 amountB) {
        address pair = ReservoirLibrary.pairFor(address(factory), tokenA, tokenB, curveId);
        IReservoirPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IReservoirPair(pair).burn(to);

        (address token0,) = ReservoirLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, "RR: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "RR: INSUFFICIENT_B_AMOUNT");
    }

    function swapExactForVariable(address pair, address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {}
    function swapVariableForExact(address pair, address tokenOut, uint256 amountOut, uint256 maxAmountIn) external returns (uint256 amountIn) {}

    function getAmountOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut) {}
    function getAmountsOut(uint256 curveId, address tokenIn, address tokenOut, uint256 amountIn) external view returns(uint256[] memory amountsOut) {}

    function getAmountIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256 amountIn) {}
    function getAmountsIn(uint256 curveId, address tokenIn, address tokenOut, uint256 amountOut) external view returns(uint256[] memory amountsIn) {}

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = factory.getPair(tokenA, tokenB, curveId);
        (uint reserveA, uint reserveB) = (0,0);
        uint tokenAPrecisionMultiplier = uint256(10) ** (18 - ERC20(tokenA).decimals());
        uint tokenBPrecisionMultiplier = uint256(10) ** (18 - ERC20(tokenB).decimals());
        uint _totalSupply = 0;

        if (pair != address(0)) {
            _totalSupply = IReservoirPair(pair).totalSupply();
            (reserveA, reserveB) = ReservoirLibrary.getReserves(address(factory), tokenA, tokenB, curveId);
        }

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
            if (curveId == 0) {
                liquidity = FixedPointMathLib.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            }
            else if (curveId == 1) {
                uint256 newLiq = ReservoirLibrary.computeStableLiquidity(
                    amountA,
                    amountB,
                    tokenAPrecisionMultiplier,
                    tokenBPrecisionMultiplier,
                    2 * StablePair(pair).getCurrentAPrecise()
                );
                liquidity = newLiq - MINIMUM_LIQUIDITY;
            }
        }
        else {
            uint amountBOptimal = ReservoirLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            }
            else {
                uint amountAOptimal = ReservoirLibrary.quote(amountBDesired, reserveB, reserveA);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }

            if (curveId == 0) {
                liquidity = Math.min(amountA * _totalSupply / reserveA, amountB * _totalSupply / reserveB);
            }
            else if (curveId == 1) {
                uint256 oldLiq = ReservoirLibrary.computeStableLiquidity(
                    reserveA,
                    reserveB,
                    tokenAPrecisionMultiplier,
                    tokenBPrecisionMultiplier,
                    2 * StablePair(pair).getCurrentAPrecise()
                );
                uint256 newLiq = ReservoirLibrary.computeStableLiquidity(
                    reserveA + amountA,
                    reserveB + amountB,
                    tokenAPrecisionMultiplier,
                    tokenBPrecisionMultiplier,
                    2 * StablePair(pair).getCurrentAPrecise()
                );
                liquidity = (newLiq - oldLiq) * _totalSupply / oldLiq;
            }
        }
    }

    // implementation from solidly
    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint256 curveId,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB) {
        address pair = factory.getPair(tokenA, tokenB, curveId);

        if (pair == address(0)) {
            return (0,0);
        }

        (uint256 reserveA, uint256 reserveB) = ReservoirLibrary.getReserves(address(factory), tokenA, tokenB, curveId);
        uint256 totalSupply = IReservoirPair(pair).totalSupply();

        amountA = liquidity * reserveA / totalSupply;
        amountB = liquidity * reserveB / totalSupply;
    }
}
