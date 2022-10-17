pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { MathUtils } from "v3-core/src/libraries/MathUtils.sol";

import { Quoter, ExtraData } from "src/Quoter.sol";
import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";

contract QuoterTest is BaseTest
{
    WETH    private _weth   = new WETH();
    Quoter  private _quoter = new Quoter(address(_factory), address(_weth));

    function testQuoteAddLiquidity(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public
    {
        // assume
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq)
            = _quoter.quoteAddLiquidity(address(_tokenA), address(_tokenB), 0, lAmountAToAdd, lAmountBToAdd);

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);
        assertEq(lLiq, FixedPointMathLib.sqrt(lAmountAOptimal * lAmountBOptimal));
    }

    function testQuoteAddLiquidity_Stable(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public
    {
        // assume
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq)
            = _quoter.quoteAddLiquidity(address(_tokenA), address(_tokenB), 1, lAmountAToAdd, lAmountBToAdd);

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);
        assertEq(lLiq, lAmountAOptimal + lAmountBOptimal);
    }

    function testQuoteRemoveLiquidity(uint256 aLiquidity) public
    {
        // assume
        uint256 lLiquidity = bound(aLiquidity, 1, _constantProductPair.balanceOf(_alice));

        // act
        (uint256 lAmountA, uint256 lAmountB) = _quoter.quoteRemoveLiquidity(address(_tokenA), address(_tokenB), 0, lLiquidity);
        vm.prank(_alice);
        _constantProductPair.transfer(address(_constantProductPair), lLiquidity);
        _constantProductPair.burn(_alice);

        // assert
        assertTrue(MathUtils.within1(lAmountA, _tokenA.balanceOf(_alice)));
        assertTrue(MathUtils.within1(lAmountB, _tokenB.balanceOf(_alice)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                        DIFFERENTIAL TESTING AGAINST LIB
    //////////////////////////////////////////////////////////////////////////*/

    function testGetAmountOutConstantProduct(uint256 aAmtIn, uint256 aReserveIn, uint256 aReserveOut, uint256 aSwapFee) public
    {
        // assume
        uint256 lAmtIn = bound(aAmtIn, 1, type(uint112).max);
        uint256 lReserveIn = bound(aReserveIn, 1, type(uint112).max);
        uint256 lReserveOut = bound(aReserveOut, 1, type(uint112).max);
        uint256 lSwapFee = bound(aSwapFee, 0, 200); // max swap fee is 2% configured in Pair.sol

        // act
        uint256 lLibOutput = ReservoirLibrary.getAmountOutConstantProduct(lAmtIn, lReserveIn, lReserveOut, lSwapFee);
        uint256 lOutput = _quoter.getAmountOut(lAmtIn, lReserveIn, lReserveOut, 0, lSwapFee, ExtraData(0,0,0));

        // assert
        assertEq(lLibOutput, lOutput);
    }

    function testGetAmountOutStable(uint256 aAmtIn, uint256 aReserveIn, uint256 aReserveOut, uint256 aSwapFee, uint256 aAmpCoeff) public
    {
        // assume
        uint256 lReserveIn = bound(aReserveIn, 1e6, type(uint112).max);
        uint256 lReserveOut = bound(aReserveOut, lReserveIn / 1e3, Math.min(lReserveIn * 1e3, type(uint112).max));
        uint256 lAmtIn = bound(aAmtIn, 1e6, type(uint112).max);
        uint256 lSwapFee = bound(aSwapFee, 0, 200);
        uint256 lAmpCoefficient = bound(aAmpCoeff, 100, 1000000);

        ExtraData memory lData = ExtraData(1, 1, uint64(lAmpCoefficient));

        // act
        uint256 lLibOutput = ReservoirLibrary.getAmountOutStable(lAmtIn, lReserveIn, lReserveOut, lSwapFee, lData);
        uint256 lOutput = _quoter.getAmountOut(lAmtIn, lReserveIn, lReserveOut, 1, lSwapFee, lData);

        // assert
        assertEq(lLibOutput, lOutput);
    }
}
