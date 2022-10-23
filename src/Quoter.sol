pragma solidity 0.8.13;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";

import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";
import { StablePair } from "v3-core/src/curve/stable/StablePair.sol";
import { Bytes32Lib } from "v3-core/src/libraries/Bytes32.sol";
import { FactoryStoreLib } from "v3-core/src/libraries/FactoryStore.sol";
import { GenericFactory } from "v3-core/src/GenericFactory.sol";
import { StableMath } from "v3-core/src/libraries/StableMath.sol";

import { IQuoter, ExtraData } from "src/interfaces/IQuoter.sol";

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";
import { PeripheryImmutableState } from "src/abstract/PeripheryImmutableState.sol";

contract Quoter is IQuoter, PeripheryImmutableState
{
    using FactoryStoreLib for GenericFactory;
    using Bytes32Lib for bytes32;

    constructor(address aFactory, address aWETH) PeripheryImmutableState(aFactory, aWETH)
    {} // solhint-disable-line no-empty-blocks

    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

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
        (uint256 lReserveA, uint256 lReserveB) = (0,0);
        uint256 lTokenAPrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(aTokenA);
        uint256 lTokenBPrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(aTokenB);
        uint256 lTotalSupply = 0;

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
                    2 * factory.read("ConstantProductPair::amplificationCoefficient").toUint64() * StableMath.A_PRECISION
                );
                rLiq = newLiq - MINIMUM_LIQUIDITY;
            }
        }
        else {
            uint256 lAmountBOptimal = ReservoirLibrary.quote(aAmountADesired, lReserveA, lReserveB);
            if (lAmountBOptimal <= aAmountBDesired) {
                (rAmountA, rAmountB) = (aAmountADesired, lAmountBOptimal);
            }
            else {
                uint256 lAmountAOptimal = ReservoirLibrary.quote(aAmountBDesired, lReserveB, lReserveA);
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
