pragma solidity 0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";
import { IGenericFactory } from "v3-core/src/interfaces/IGenericFactory.sol";
import { ExtraData } from "src/interfaces/IReservoirRouter.sol";

import { ConstantProductPair } from "v3-core/src/curve/constant-product/ConstantProductPair.sol";
import { StablePair } from "v3-core/src/curve/stable/StablePair.sol";

import { StableMath } from "v3-core/src/libraries/StableMath.sol";

library ReservoirLibrary {
    uint256 public constant FEE_ACCURACY  = 10_000;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "RL: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "RL: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB, uint256 curveId) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        bytes memory lInitCode;

        if (curveId == 0) {
            lInitCode = abi.encodePacked(type(ConstantProductPair).creationCode, abi.encode(token0, token1));
        }
        else if (curveId == 1) {
            lInitCode = abi.encodePacked(type(StablePair).creationCode, abi.encode(token0, token1));
        }
        else {
            revert("RL: CURVE_DOES_NOT_EXIST");
        }

        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                factory,
                bytes32(0),
                keccak256(lInitCode)
            )))));
    }

    function getSwapFee(address factory, address tokenA, address tokenB, uint256 curveId) internal view returns (uint swapFee) {
        swapFee = IReservoirPair(pairFor(factory, tokenA, tokenB, curveId)).swapFee();
    }

    // does not support tokens with > 18 decimals
    function getPrecisionMultiplier(address token) internal view returns (uint256 precisionMultiplier) {
        precisionMultiplier = 10 ** (18 - ERC20(token).decimals());
    }

    // returns the precise amplification coefficient for calculation purposes
    function getAmplificationCoefficient(address pair) internal view returns (uint256 amplificationCoefficient) {
        amplificationCoefficient = StablePair(pair).getCurrentAPrecise();
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB,
        uint256 curveId
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IReservoirPair(pairFor(factory, tokenA, tokenB, curveId)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // this works for both ConstantProduct and Stable pairs
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, "RL: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "RL: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }

    function computeStableLiquidity(
        uint256 reserve0,
        uint256 reserve1,
        uint256 token0PrecisionMultiplier,
        uint256 token1PrecisionMultiplier,
        uint256 N_A
    ) internal pure returns (uint256) {
        return StableMath._computeLiquidityFromAdjustedBalances(
            reserve0 * token0PrecisionMultiplier,
            reserve1 * token1PrecisionMultiplier,
            N_A
        );
    }

    function getAmountOutConstantProduct(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "RL: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");
        uint amountInWithFee = amountIn * (FEE_ACCURACY - swapFee);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * FEE_ACCURACY + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountInConstantProduct(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "RL: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");
        uint numerator = reserveIn * amountOut * FEE_ACCURACY;
        uint denominator = (reserveOut - amountOut) * (FEE_ACCURACY - swapFee);
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOutStable(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee,
        ExtraData memory data
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "RL: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");

        amountOut = StableMath._getAmountOut(
            amountIn,
            reserveIn,
            reserveOut,
            data.token0PrecisionMultiplier,
            data.token1PrecisionMultiplier,
            true,
            swapFee,
            2 * data.amplificationCoefficient
        );
    }

    function getAmountInStable(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee,
        ExtraData calldata data
    ) internal pure returns (uint256 amountIn) {
        require(amountIn > 0, "RL: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "RL: INSUFFICIENT_LIQUIDITY");

        amountIn = StableMath._getAmountIn(
            amountOut,
            reserveIn,
            reserveOut,
            data.token0PrecisionMultiplier,
            data.token1PrecisionMultiplier,
            false,
            swapFee,
            2 * data.amplificationCoefficient
        );
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] calldata path,
        uint256[] calldata curveIds
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "RL: INVALID_PATH");
        require(curveIds.length == path.length - 1, "RL: CURVE_IDS_INVALID_LENGTH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; ++i) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1], curveIds[i]);
            uint swapFee = getSwapFee(factory, path[i], path[i + 1], curveIds[i]);
            if (curveIds[i] == 0) {
                amounts[i + 1] = getAmountOutConstantProduct(amounts[i], reserveIn, reserveOut, swapFee);
            }
            else if (curveIds[i] == 1) {
                ExtraData memory data = ExtraData(
                    uint64(getPrecisionMultiplier(path[i])),
                    uint64(getPrecisionMultiplier(path[i + 1])),
                    uint64(getAmplificationCoefficient(pairFor(factory, path[i], path[i + 1], 1)))
                );
                amounts[i + 1] = getAmountOutStable(amounts[i], reserveIn, reserveOut, swapFee, data);
            }
        }
    }
}
