pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { MathUtils } from "v3-core/src/libraries/MathUtils.sol";
import { StableMath } from "v3-core/src/libraries/StableMath.sol";

import { Quoter, ExtraData } from "src/Quoter.sol";
import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";

contract QuoterTest is BaseTest {
    using FixedPointMathLib for uint256;

    WETH private _weth = new WETH();
    Quoter private _quoter = new Quoter(address(_factory), address(_weth));

    function testQuoteAddLiquidity_PairDoesNotExistYet(uint256 aAmountBToAdd, uint256 aAmountCToAdd, uint256 aCurveId)
        public
    {
        // assume
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 60_000_000e18, 100_000_000e18);
        uint256 lAmountCToAdd = bound(aAmountCToAdd, 120_000_000e18, 180_000_000e18);
        uint256 lCurveId = bound(aCurveId, 0, 1);

        // act
        (uint256 lAmountBOptimal, uint256 lAmountCOptimal, uint256 lLiq) =
            _quoter.quoteAddLiquidity(address(_tokenB), address(_tokenC), lCurveId, lAmountBToAdd, lAmountCToAdd);

        // assert
        assertEq(lAmountBOptimal, lAmountBToAdd);
        assertEq(lAmountCOptimal, lAmountCToAdd);
        if (lCurveId == 0) {
            assertEq(lLiq, FixedPointMathLib.sqrt(lAmountBToAdd * lAmountCToAdd) - _quoter.MINIMUM_LIQUIDITY());
        } else if (lCurveId == 1) {
            uint256 lExpectedStableLiq = ReservoirLibrary.computeStableLiquidity(
                lAmountBToAdd, lAmountCToAdd, 1, 1, 2 * DEFAULT_AMP_COEFF * StableMath.A_PRECISION
            );
            assertEq(lLiq, lExpectedStableLiq - _quoter.MINIMUM_LIQUIDITY());
        }
    }

    function testQuoteAddLiquidity_ConstantProduct_Balanced(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public {
        // assume
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max - INITIAL_MINT_AMOUNT);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max - INITIAL_MINT_AMOUNT);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq) =
            _quoter.quoteAddLiquidity(address(_tokenA), address(_tokenB), 0, lAmountAToAdd, lAmountBToAdd);

        // do actual mint
        _tokenA.mint(address(_constantProductPair), lAmountAOptimal);
        _tokenB.mint(address(_constantProductPair), lAmountBOptimal);
        uint256 lActualLiq = _constantProductPair.mint(address(this));

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);
        assertEq(lLiq, FixedPointMathLib.sqrt(lAmountAOptimal * lAmountBOptimal));
        assertEq(lLiq, lActualLiq);
    }

    function testQuoteAddLiquidity_ConstantProduct_Unbalanced(
        uint256 aAmountBToMint,
        uint256 aAmountCToMint,
        uint256 aAmountBToAdd,
        uint256 aAmountCToAdd
    ) public {
        // assume
        uint256 lAmountBToMint = bound(aAmountBToMint, 100_000e18, 400_000e18);
        uint256 lAmountCToMint = bound(aAmountCToMint, 600_000e18, 2_000_000e18);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1e6, type(uint112).max - lAmountBToMint);
        uint256 lAmountCToAdd = bound(aAmountCToAdd, 1e6, type(uint112).max - lAmountCToMint);

        // arrange
        ConstantProductPair lPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
        _tokenB.mint(address(lPair), lAmountBToMint);
        _tokenC.mint(address(lPair), lAmountCToMint);
        lPair.mint(address(this));
        uint256 lTotalSupply = lPair.totalSupply();

        // act
        (uint256 lAmountBOptimal, uint256 lAmountCOptimal, uint256 lExpectedLiq) =
            _quoter.quoteAddLiquidity(address(_tokenB), address(_tokenC), 0, lAmountBToAdd, lAmountCToAdd);

        // do actual mint
        _tokenB.mint(address(lPair), lAmountBOptimal);
        _tokenC.mint(address(lPair), lAmountCOptimal);
        uint256 lActualLiq = lPair.mint(address(this));

        // assert
        assertTrue(lAmountBOptimal != lAmountCOptimal);
        assertEq(
            lExpectedLiq,
            Math.min(lAmountBOptimal * lTotalSupply / lAmountBToMint, lAmountCOptimal * lTotalSupply / lAmountCToMint)
        );
        assertEq(lActualLiq, lExpectedLiq);
        // check that they are in the same proportions
        assertApproxEqRel(
            lAmountBOptimal.divWadDown(lAmountCOptimal), lAmountBToMint.divWadDown(lAmountCToMint), 0.0001e18
        ); // 1 bp
    }

    function testQuoteAddLiquidity_Stable_Balanced(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public {
        // assume
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max - INITIAL_MINT_AMOUNT);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max - INITIAL_MINT_AMOUNT);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq) =
            _quoter.quoteAddLiquidity(address(_tokenA), address(_tokenB), 1, lAmountAToAdd, lAmountBToAdd);

        // do actual mint
        _tokenA.mint(address(_stablePair), lAmountAOptimal);
        _tokenB.mint(address(_stablePair), lAmountBOptimal);
        uint256 lActualLiq = _stablePair.mint(address(this));

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);
        assertEq(lLiq, lAmountAOptimal + lAmountBOptimal);
        assertEq(lLiq, lActualLiq);
    }

    function testQuoteAddLiquidity_Stable_Unbalanced(
        uint256 aAmountBToMint,
        uint256 aAmountCToMint,
        uint256 aAmountBToAdd,
        uint256 aAmountCToAdd
    ) public {
        // assume
        uint256 lAmountBToMint = bound(aAmountBToMint, 100_000e18, 400_000e18);
        uint256 lAmountCToMint = bound(aAmountCToMint, 600_000e18, 2_000_000e18);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000e10, type(uint112).max - lAmountBToMint);
        uint256 lAmountCToAdd = bound(aAmountCToAdd, 1000e10, type(uint112).max - lAmountCToMint);

        // arrange
        StablePair lPair = StablePair(_createPair(address(_tokenB), address(_tokenC), 1));
        _tokenB.mint(address(lPair), lAmountBToMint);
        _tokenC.mint(address(lPair), lAmountCToMint);
        lPair.mint(address(this));

        // act
        (uint256 lAmountBOptimal, uint256 lAmountCOptimal, uint256 lExpectedLiq) =
            _quoter.quoteAddLiquidity(address(_tokenB), address(_tokenC), 1, lAmountBToAdd, lAmountCToAdd);

        // do actual mint
        _tokenB.mint(address(lPair), lAmountBOptimal);
        _tokenC.mint(address(lPair), lAmountCOptimal);
        uint256 lActualLiq = lPair.mint(address(this));

        // assert
        assertLt(lAmountBOptimal, lAmountCOptimal);
        assertLe(lAmountBOptimal, lAmountBToAdd);
        assertLe(lAmountCOptimal, lAmountCToAdd);
        assertLt(lActualLiq, lAmountBOptimal + lAmountCOptimal);
        assertEq(lExpectedLiq, lActualLiq);
        // check that they are in the same proportions
        assertApproxEqRel(
            lAmountBOptimal.divWadDown(lAmountCOptimal), lAmountBToMint.divWadDown(lAmountCToMint), 0.00001e18
        ); // 0.1 bp
    }

    function testQuoteRemoveLiquidity(uint256 aLiquidity) public {
        // assume
        uint256 lLiquidity = bound(aLiquidity, 1, _constantProductPair.balanceOf(_alice));

        // act
        (uint256 lAmountA, uint256 lAmountB) =
            _quoter.quoteRemoveLiquidity(address(_tokenA), address(_tokenB), 0, lLiquidity);
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

    function testGetAmountOutConstantProduct(uint256 aAmtIn, uint256 aReserveIn, uint256 aReserveOut, uint256 aSwapFee)
        public
    {
        // assume
        uint256 lAmtIn = bound(aAmtIn, 1, type(uint112).max);
        uint256 lReserveIn = bound(aReserveIn, 1, type(uint112).max);
        uint256 lReserveOut = bound(aReserveOut, 1, type(uint112).max);
        uint256 lSwapFee = bound(aSwapFee, 0, 200); // max swap fee is 2% configured in Pair.sol

        // act
        uint256 lLibOutput = ReservoirLibrary.getAmountOutConstantProduct(lAmtIn, lReserveIn, lReserveOut, lSwapFee);
        uint256 lOutput = _quoter.getAmountOut(lAmtIn, lReserveIn, lReserveOut, 0, lSwapFee, ExtraData(0, 0, 0));

        // assert
        assertEq(lLibOutput, lOutput);
    }

    function testGetAmountOutStable(
        uint256 aAmtIn,
        uint256 aReserveIn,
        uint256 aReserveOut,
        uint256 aSwapFee,
        uint256 aAmpCoeff
    ) public {
        // assume
        uint256 lReserveIn = bound(aReserveIn, 1e6, type(uint112).max);
        uint256 lReserveOut = bound(aReserveOut, lReserveIn / 1e3, Math.min(lReserveIn * 1e3, type(uint112).max));
        uint256 lAmtIn = bound(aAmtIn, 1e6, type(uint112).max);
        uint256 lSwapFee = bound(aSwapFee, 0, 200);
        uint256 lAmpCoefficient =
            bound(aAmpCoeff, StableMath.MIN_A * StableMath.A_PRECISION, StableMath.MAX_A * StableMath.A_PRECISION);

        ExtraData memory lData = ExtraData(1, 1, uint64(lAmpCoefficient));

        // act
        uint256 lLibOutput = ReservoirLibrary.getAmountOutStable(lAmtIn, lReserveIn, lReserveOut, lSwapFee, lData);
        uint256 lOutput = _quoter.getAmountOut(lAmtIn, lReserveIn, lReserveOut, 1, lSwapFee, lData);

        // assert
        assertEq(lLibOutput, lOutput);
    }

    function testGetAmountsOut(uint256 aAmtIn, uint256 aAmtB, uint256 aAmtD) public {
        // assume
        uint256 lAmtIn = bound(aAmtIn, 1e6, type(uint112).max);
        uint256 lAmtBToMint = bound(aAmtB, 1001, type(uint112).max / 2);
        uint256 lAmtDToMint = bound(aAmtD, 1001, type(uint112).max / 2);

        // arrange
        ConstantProductPair lNewPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenD), 0));
        _tokenB.mint(address(lNewPair), lAmtBToMint);
        _tokenD.mint(address(lNewPair), lAmtDToMint);
        lNewPair.mint(address(this));
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenD);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 0;

        // act
        uint256[] memory lLibOutput = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);
        uint256[] memory lOutput = _quoter.getAmountsOut(lAmtIn, lPath, lCurveIds);

        // assert
        assertEq(lLibOutput, lOutput);
    }

    function testGetAmountsIn(uint256 aAmtOut) public {
        // assume
        uint256 lAmtOut = bound(aAmtOut, 1, INITIAL_MINT_AMOUNT / 3);

        // arrange
        ConstantProductPair lNewPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenD), 0));
        _tokenB.mint(address(lNewPair), INITIAL_MINT_AMOUNT);
        _tokenD.mint(address(lNewPair), INITIAL_MINT_AMOUNT);
        lNewPair.mint(address(this));
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenD);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 0;

        // act
        uint256[] memory lLibOutput = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);
        uint256[] memory lOutput = _quoter.getAmountsIn(lAmtOut, lPath, lCurveIds);

        // assert
        assertEq(lLibOutput, lOutput);
    }
}
