pragma solidity 0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";

import { IReservoirRouter, ExtraData } from "src/interfaces/IReservoirRouter.sol";
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

    constructor (address aFactory, address aWETH) PeripheryImmutableState(aFactory, aWETH)
    {}

    function _addLiquidity(
        address aTokenA,
        address aTokenB,
        uint aCurveId,
        uint aAmountADesired,
        uint aAmountBDesired,
        uint aAmountAMin,
        uint aAmountBMin
    ) private returns (uint rAmountA, uint rAmountB, address rPair) {
        rPair = factory.getPair(aTokenA, aTokenB, aCurveId);

        if (rPair == address(0)) {
            rPair = factory.createPair(aTokenA, aTokenB, aCurveId);
        }

        (uint256 lReserveA, uint256 lReserveB) = ReservoirLibrary.getReserves(address(factory), aTokenA, aTokenB, aCurveId);
        if (lReserveA == 0 && lReserveB == 0) {
            (rAmountA, rAmountB) = (aAmountADesired, aAmountBDesired);
        }
        else {
            uint lAmountBOptimal = ReservoirLibrary.quote(aAmountADesired, lReserveA, lReserveB);
            if (lAmountBOptimal <= aAmountBDesired) {
                require(lAmountBOptimal >= aAmountBMin, "RR: INSUFFICIENT_B_AMOUNT");
                (rAmountA, rAmountB) = (aAmountADesired, lAmountBOptimal);
            } else {
                uint lAmountAOptimal = ReservoirLibrary.quote(aAmountBDesired, lReserveB, lReserveA);
                assert(lAmountAOptimal <= aAmountADesired);
                require(lAmountAOptimal >= aAmountAMin, "RR: INSUFFICIENT_A_AMOUNT");
                (rAmountA, rAmountB) = (lAmountAOptimal, aAmountBDesired);
            }
        }
    }

    function addLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint aAmountADesired,
        uint aAmountBDesired,
        uint aAmountAMin,
        uint aAmountBMin,
        address aTo
    ) external payable returns (uint256 rAmountA, uint256 rAmountB, uint256 rLiq) {
        address lPair;
        (rAmountA, rAmountB, lPair) = _addLiquidity(aTokenA, aTokenB, aCurveId, aAmountADesired, aAmountBDesired, aAmountAMin, aAmountBMin);

        _pay(aTokenA, msg.sender, lPair, rAmountA);
        _pay(aTokenB, msg.sender, lPair, rAmountB);

        rLiq = IReservoirPair(lPair).mint(aTo);
    }

    function removeLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aLiq,
        uint256 aAmountAMin,
        uint256 aAmountBMin,
        address aTo // when withdrawing to the router in UniV3, this address is 0. But we can just put the router's address
    ) external /*payable*/ returns (uint256 rAmountA, uint256 rAmountB) {
        address lPair = ReservoirLibrary.pairFor(address(factory), aTokenA, aTokenB, aCurveId);
        IReservoirPair(lPair).transferFrom(msg.sender, lPair, aLiq); // send liquidity to lPair
        (uint lAmount0, uint lAmount1) = IReservoirPair(lPair).burn(aTo);

        (address lToken0,) = ReservoirLibrary.sortTokens(aTokenA, aTokenB);
        (rAmountA, rAmountB) = aTokenA == lToken0 ? (lAmount0, lAmount1) : (lAmount1, lAmount0);

        require(rAmountA >= aAmountAMin, "RR: INSUFFICIENT_A_AMOUNT");
        require(rAmountB >= aAmountBMin, "RR: INSUFFICIENT_B_AMOUNT");
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    /// @param aInOrOut true for exact in, false for exact out
    function _swap(uint[] memory aAmounts, bool aInOrOut, address[] memory aPath, uint256[] memory aCurveIds, address aTo) internal {
        for (uint i; i < aPath.length - 1; ) {
            (address lInput, address lOutput) = (aPath[i], aPath[i + 1]);
            (address lToken0,) = ReservoirLibrary.sortTokens(lInput, lOutput);
            address lTo = i < aPath.length - 2 ? ReservoirLibrary.pairFor(address(factory), lOutput, aPath[i + 2], aCurveIds[i + 1]) : aTo;

            int256 lAmount;
            if (aInOrOut) {
                lAmount = lInput == lToken0 ? int256(aAmounts[i]) : -int256(aAmounts[i]);
            }
            else {
                lAmount = lOutput == lToken0 ? int256(aAmounts[i + 1]) : -int256(aAmounts[i + 1]);
            }

            IReservoirPair(ReservoirLibrary.pairFor(address(factory), lInput, lOutput, aCurveIds[i])).swap(
                lAmount, aInOrOut, lTo, new bytes(0)
            );

            unchecked { i += 1; }
        }
    }

    function swapExactForVariable(
        uint256 aAmountIn,
        uint256 aAmountOutMin,
        address[] calldata aPath,
        uint256[] calldata aCurveIds,
        address aTo
    ) external payable returns (uint256[] memory rAmounts) {
        rAmounts = ReservoirLibrary.getAmountsOut(address(factory), aAmountIn, aPath, aCurveIds);
        // but the actual swap results might be diff from this. Should we move the require into _swap to check for the minOut?
        require(rAmounts[rAmounts.length - 1] >= aAmountOutMin, "RL: INSUFFICIENT_OUTPUT_AMOUNT");

        _pay(aPath[0], msg.sender, ReservoirLibrary.pairFor(address(factory), aPath[0], aPath[1], aCurveIds[0]), rAmounts[0]);
        _swap(rAmounts, true, aPath, aCurveIds, aTo);
    }

    function swapVariableForExact(
        uint256 aAmountOut,
        uint256 aAmountInMax,
        address[] calldata aPath,
        uint256[] calldata aCurveIds,
        address aTo
    ) external payable returns (uint256[] memory rAmounts) {
        rAmounts = ReservoirLibrary.getAmountsIn(address(factory), aAmountOut, aPath, aCurveIds);
        require(rAmounts[0] <= aAmountInMax, "RL: EXCESSIVE_INPUT_AMOUNT");

        _pay(aPath[0], msg.sender, ReservoirLibrary.pairFor(address(factory), aPath[0], aPath[1], aCurveIds[0]), rAmounts[0]);
        _swap(rAmounts, false, aPath, aCurveIds, aTo);
    }

    function getAmountOut(
        uint256 aAmountIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns (uint256 rAmountOut) {
        if (aCurveId == 0) {
            rAmountOut = ReservoirLibrary.getAmountOutConstantProduct(aAmountIn, aReserveIn, aReserveOut, aSwapFee);
        }
        else if (aCurveId == 1) {
            rAmountOut = ReservoirLibrary.getAmountOutStable(aAmountIn, aReserveIn, aReserveOut, aSwapFee, aExtraData);
        }
    }

    function getAmountIn(
        uint256 aAmountOut,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aCurveId,
        uint256 aSwapFee,
        ExtraData calldata aExtraData
    ) external pure returns (uint256 rAmountIn) {
        if (aCurveId == 0) {
            rAmountIn = ReservoirLibrary.getAmountInConstantProduct(aAmountOut, aReserveIn, aReserveOut, aSwapFee);
        }
        else if (aCurveId == 1) {
            rAmountIn = ReservoirLibrary.getAmountInStable(aAmountOut, aReserveIn, aReserveOut, aSwapFee, aExtraData);
        }
    }

    function getAmountsOut(
        uint256 aAmountIn,
        address[] calldata aPath,
        uint256[] calldata aCurveIds
    ) external view returns(uint256[] memory rAmountsOut) {
        rAmountsOut = ReservoirLibrary.getAmountsOut(address(factory), aAmountIn, aPath, aCurveIds);
    }

    function getAmountsIn(
        uint256 aAmountOut,
        address[] calldata aPath,
        uint256[] calldata aCurveIds
    ) external view returns(uint256[] memory rAmountsIn) {
        rAmountsIn = ReservoirLibrary.getAmountsIn(address(factory), aAmountOut, aPath, aCurveIds);
    }

    function quoteAddLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aAmountADesired,
        uint256 aAmountBDesired
    ) external view returns (uint256 rAmountA, uint256 rAmountB, uint256 rLiq) {
        address lPair = factory.getPair(aTokenA, aTokenB, aCurveId);
        (uint lReserveA, uint lReserveB) = (0,0);
        uint lTokenAPrecisionMultiplier = uint256(10) ** (18 - ERC20(aTokenA).decimals());
        uint lTokenBPrecisionMultiplier = uint256(10) ** (18 - ERC20(aTokenB).decimals());
        uint lTotalSupply = 0;

        if (lPair != address(0)) {
            lTotalSupply = IReservoirPair(lPair).totalSupply();
            (lReserveA, lReserveB) = ReservoirLibrary.getReserves(address(factory), aTokenA, aTokenB, aCurveId);
        }

        if (lReserveA == 0 && lReserveB == 0) {
            (rAmountA, rAmountB) = (aAmountADesired, aAmountBDesired);
            if (aCurveId == 0) {
                rLiq = FixedPointMathLib.sqrt(rAmountA * rAmountB) - MINIMUM_LIQUIDITY;
            }
            else if (aCurveId == 1) {
                uint256 newLiq = ReservoirLibrary.computeStableLiquidity(
                    rAmountA,
                    rAmountB,
                    lTokenAPrecisionMultiplier,
                    lTokenBPrecisionMultiplier,
                    2 * StablePair(lPair).getCurrentAPrecise()
                );
                rLiq = newLiq - MINIMUM_LIQUIDITY;
            }
        }
        else {
            uint lAmountBOptimal = ReservoirLibrary.quote(aAmountADesired, lReserveA, lReserveB);
            if (lAmountBOptimal <= aAmountBDesired) {
                (rAmountA, rAmountB) = (aAmountADesired, lAmountBOptimal);
            }
            else {
                uint lAmountAOptimal = ReservoirLibrary.quote(aAmountBDesired, lReserveB, lReserveA);
                (rAmountA, rAmountB) = (lAmountAOptimal, aAmountBDesired);
            }

            if (aCurveId == 0) {
                rLiq = Math.min(rAmountA * lTotalSupply / lReserveA, rAmountB * lTotalSupply / lReserveB);
            }
            else if (aCurveId == 1) {
                uint256 oldLiq = ReservoirLibrary.computeStableLiquidity(
                    lReserveA,
                    lReserveB,
                    lTokenAPrecisionMultiplier,
                    lTokenBPrecisionMultiplier,
                    2 * StablePair(lPair).getCurrentAPrecise()
                );
                uint256 newLiq = ReservoirLibrary.computeStableLiquidity(
                    lReserveA + rAmountA,
                    lReserveB + rAmountB,
                    lTokenAPrecisionMultiplier,
                    lTokenBPrecisionMultiplier,
                    2 * StablePair(lPair).getCurrentAPrecise()
                );
                rLiq = (newLiq - oldLiq) * lTotalSupply / oldLiq;
            }
        }
    }

    function quoteRemoveLiquidity(
        address aTokenA,
        address aTokenB,
        uint256 aCurveId,
        uint256 aLiq
    ) external view returns (uint256 rAmountA, uint256 rAmountB) {
        address lPair = factory.getPair(aTokenA, aTokenB, aCurveId);

        if (lPair == address(0)) {
            return (0,0);
        }

        (uint256 lReserveA, uint256 lReserveB) = ReservoirLibrary.getReserves(address(factory), aTokenA, aTokenB, aCurveId);
        uint256 lTotalSupply = IReservoirPair(lPair).totalSupply();

        rAmountA = aLiq * lReserveA / lTotalSupply;
        rAmountB = aLiq * lReserveB / lTotalSupply;
    }
}
