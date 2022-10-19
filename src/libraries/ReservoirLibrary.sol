pragma solidity 0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";
import { IGenericFactory } from "v3-core/src/interfaces/IGenericFactory.sol";
import { ExtraData } from "src/interfaces/IQuoter.sol";

import { ConstantProductPair } from "v3-core/src/curve/constant-product/ConstantProductPair.sol";
import { StablePair } from "v3-core/src/curve/stable/StablePair.sol";

import { StableMath } from "v3-core/src/libraries/StableMath.sol";

library ReservoirLibrary {
    uint256 public constant FEE_ACCURACY  = 1_000_000;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address aTokenA, address aTokenB) internal pure returns (address rToken0, address rToken1) {
        require(aTokenA != aTokenB, "RL: IDENTICAL_ADDRESSES");
        (rToken0, rToken1) = aTokenA < aTokenB ? (aTokenA, aTokenB) : (aTokenB, aTokenA);
        require(rToken0 != address(0), "RL: ZERO_ADDRESS");
    }

    /// @notice queries the factory for the actual pair address
    function pairFor(address aFactory, address aTokenA, address aTokenB, uint256 aCurveId) internal view returns (address rPair) {
        rPair = IGenericFactory(aFactory).getPair(aTokenA, aTokenB, aCurveId);
    }

    function getSwapFee(address aFactory, address aTokenA, address aTokenB, uint256 aCurveId) internal view returns (uint rSwapFee) {
        rSwapFee = IReservoirPair(pairFor(aFactory, aTokenA, aTokenB, aCurveId)).swapFee();
    }

    // does not support tokens with > 18 decimals
    function getPrecisionMultiplier(address aToken) internal view returns (uint64 rPrecisionMultiplier) {
        rPrecisionMultiplier = uint64(10 ** (18 - ERC20(aToken).decimals()));
    }

    // returns the precise amplification coefficient for calculation purposes
    function getAmplificationCoefficient(address aPair) internal view returns (uint64 rAmplificationCoefficient) {
        rAmplificationCoefficient = StablePair(aPair).getCurrentAPrecise();
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address aFactory,
        address aTokenA,
        address aTokenB,
        uint256 aCurveId
    ) internal view returns (uint256 rReserveA, uint256 rReserveB) {
        (address lToken0,) = sortTokens(aTokenA, aTokenB);
        (uint lReserve0, uint lReserve1,) = IReservoirPair(pairFor(aFactory, aTokenA, aTokenB, aCurveId)).getReserves();
        (rReserveA, rReserveB) = aTokenA == lToken0 ? (lReserve0, lReserve1) : (lReserve1, lReserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // this works for both ConstantProduct and Stable pairs
    function quote(uint aAmountA, uint aReserveA, uint aReserveB) internal pure returns (uint rAmountB) {
        require(aAmountA > 0, "RL: INSUFFICIENT_AMOUNT");
        require(aReserveA > 0 && aReserveB > 0, "RL: INSUFFICIENT_LIQUIDITY");
        unchecked {
            rAmountB = aAmountA * aReserveB / aReserveA;
        }
    }

    function computeStableLiquidity(
        uint256 aReserve0,
        uint256 aReserve1,
        uint256 aToken0PrecisionMultiplier,
        uint256 aToken1PrecisionMultiplier,
        uint256 aN_A //solhint-disable-line var-name-mixedcase
    ) internal pure returns (uint256) {
        return StableMath._computeLiquidityFromAdjustedBalances(
            aReserve0 * aToken0PrecisionMultiplier,
            aReserve1 * aToken1PrecisionMultiplier,
            aN_A
        );
    }

    function getAmountOutConstantProduct(
        uint256 aAmountIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aSwapFee
    ) internal pure returns (uint256 rAmountOut) {
        require(aAmountIn > 0, "RL: INSUFFICIENT_INPUT_AMOUNT");
        require(aReserveIn > 0 && aReserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");
        uint lAmountInWithFee = aAmountIn * (FEE_ACCURACY - aSwapFee);
        uint lNumerator = lAmountInWithFee * aReserveOut;
        uint lDenominator = aReserveIn * FEE_ACCURACY + lAmountInWithFee;
        rAmountOut = lNumerator / lDenominator;
    }

    function getAmountInConstantProduct(
        uint256 aAmountOut,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aSwapFee
    ) internal pure returns (uint256 rAmountIn) {
        require(aAmountOut > 0, "RL: INSUFFICIENT_OUTPUT_AMOUNT");
        require(aReserveIn > 0 && aReserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");
        uint lNumerator = aReserveIn * aAmountOut * FEE_ACCURACY;
        uint lDenominator = (aReserveOut - aAmountOut) * (FEE_ACCURACY - aSwapFee);
        rAmountIn = (lNumerator / lDenominator) + 1;
    }

    function getAmountOutStable(
        uint256 aAmountIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aSwapFee,
        ExtraData memory aData
    ) internal pure returns (uint256 rAmountOut) {
        require(aAmountIn > 0, "RL: INSUFFICIENT_INPUT_AMOUNT");
        require(aReserveIn > 0 && aReserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");

        rAmountOut = StableMath._getAmountOut(
            aAmountIn,
            aReserveIn,
            aReserveOut,
            aData.token0PrecisionMultiplier,
            aData.token1PrecisionMultiplier,
            true,
            aSwapFee,
            2 * aData.amplificationCoefficient
        );
    }

    function getAmountInStable(
        uint256 aAmountOut,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aSwapFee,
        ExtraData memory aData
    ) internal pure returns (uint256 rAmountIn) {
        require(aAmountOut > 0, "RL: INSUFFICIENT_OUTPUT_AMOUNT");
        require(aReserveIn > 0 && aReserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");

        rAmountIn = StableMath._getAmountIn(
            aAmountOut,
            aReserveIn,
            aReserveOut,
            aData.token0PrecisionMultiplier,
            aData.token1PrecisionMultiplier,
            false,
            aSwapFee,
            2 * aData.amplificationCoefficient
        );
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address aFactory,
        uint256 aAmountIn,
        address[] memory aPath,
        uint256[] memory aCurveIds
    ) internal view returns (uint256[] memory rAmounts) {
        require(aPath.length >= 2, "RL: INVALID_PATH");
        require(aCurveIds.length == aPath.length - 1, "RL: CURVE_IDS_INVALID_LENGTH");
        rAmounts = new uint[](aPath.length);
        rAmounts[0] = aAmountIn;
        for (uint i = 0; i < aPath.length - 1; ) {
            (uint lReserveIn, uint lReserveOut) = getReserves(aFactory, aPath[i], aPath[i + 1], aCurveIds[i]);
            uint lSwapFee = getSwapFee(aFactory, aPath[i], aPath[i + 1], aCurveIds[i]);
            if (aCurveIds[i] == 0) {
                rAmounts[i + 1] = getAmountOutConstantProduct(rAmounts[i], lReserveIn, lReserveOut, lSwapFee);
            }
            else if (aCurveIds[i] == 1) {
                ExtraData memory lData = ExtraData(
                    // PERF: Investigate avoiding all these external calls for precision & amplification
                    uint64(getPrecisionMultiplier(aPath[i])),
                    uint64(getPrecisionMultiplier(aPath[i + 1])),
                    uint64(getAmplificationCoefficient(pairFor(aFactory, aPath[i], aPath[i + 1], 1)))
                );
                rAmounts[i + 1] = getAmountOutStable(rAmounts[i], lReserveIn, lReserveOut, lSwapFee, lData);
            }
            unchecked { i += 1; }
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address aFactory,
        uint256 aAmountOut,
        address[] memory aPath,
        uint256[] memory aCurveIds
    ) internal view returns (uint[] memory rAmounts) {
        require(aPath.length >= 2, "RL: INVALID_PATH");
        require(aCurveIds.length == aPath.length - 1, "RL: CURVE_IDS_INVALID_LENGTH");
        rAmounts = new uint[](aPath.length);
        rAmounts[rAmounts.length - 1] = aAmountOut;
        for (uint i = aPath.length - 1; i > 0; ) {
            (uint lReserveIn, uint lReserveOut) = getReserves(aFactory, aPath[i - 1], aPath[i], aCurveIds[i - 1]);
            uint lSwapFee = getSwapFee(aFactory, aPath[i - 1], aPath[i], aCurveIds[i - 1]);
            if (aCurveIds[i - 1] == 0) {
                rAmounts[i - 1] = getAmountInConstantProduct(rAmounts[i], lReserveIn, lReserveOut, lSwapFee);
            }
            else if (aCurveIds[i - 1] == 1) {
                ExtraData memory lData = ExtraData(
                    // PERF: Investigate avoiding all these external calls for precision & amplification
                    uint64(getPrecisionMultiplier(aPath[i - 1])),
                    uint64(getPrecisionMultiplier(aPath[i])),
                    uint64(getAmplificationCoefficient(pairFor(aFactory, aPath[i], aPath[i - 1], 1)))
                );
                rAmounts[i - 1] = getAmountInStable(rAmounts[i], lReserveIn, lReserveOut, lSwapFee, lData);
            }
            unchecked{ i -= 1; }
        }
    }
}
