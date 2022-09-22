pragma solidity ^0.8.0;

import { IReservoirPair } from "v3-core/src/interfaces/IReservoirPair.sol";
import { IGenericFactory } from "v3-core/src/interfaces/IGenericFactory.sol";

import { ConstantProductPair } from "v3-core/src/curve/constant-product/ConstantProductPair.sol";
import { StablePair } from "v3-core/src/curve/stable/StablePair.sol";

library ReservoirLibrary {

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "ReservoirLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ReservoirLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(IGenericFactory factory, address tokenA, address tokenB, uint256 curveId) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        if (curveId == 0) {
            bytes memory lInitCode = abi.encodePacked(type(ConstantProductPair).creationCode, abi.encode(token0, token1));

            pair = address(uint160(uint256(keccak256(abi.encodePacked(
                    bytes1(0xff),
                    address(factory),
                    bytes32(0),
                    keccak256(lInitCode)
                )))));
        }
        else if (curveId == 1) {
            bytes memory lInitCode = abi.encodePacked(type(StablePair).creationCode, abi.encode(token0, token1));

            pair = address(uint160(uint256(keccak256(abi.encodePacked(
                    bytes1(0xff),
                    address(factory),
                    bytes32(0),
                    keccak256(lInitCode)
                )))));
        }
        else {
            revert("RL: CURVE_DOES_NOT_EXIST");
        }
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        IGenericFactory factory,
        address tokenA,
        address tokenB,
        uint256 curveId
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IReservoirPair(pairFor(factory, tokenA, tokenB, curveId)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // todo: to cater for StablePair as well
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }
}
