pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { ExtraData } from "src/interfaces/IQuoter.sol";

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";
import { DummyReservoirLibrary } from "test/dummy/DummyReservoirLibrary.sol";

contract ReservoirLibraryTest is BaseTest {
    DummyReservoirLibrary private lReservoirLib = new DummyReservoirLibrary();

    function testGetSwapFee() public {
        // assert
        assertEq(ReservoirLibrary.getSwapFee(address(_factory), address(_tokenA), address(_tokenB), 0), 3000);
    }

    // commented out as vm.expectRevert does not work properly on library functions
    function testGetSwapFee_PairDoesNotExist() public {
        // act & assert
        vm.expectRevert();
        lReservoirLib.getSwapFee(address(_factory), address(_tokenA), address(_tokenC), 0);
    }

    function testGetPrecisionMultiplier() public {
        // arrange
        MintableERC20 l0DecimalToken = new MintableERC20("zero", "0", 0);

        // act & assert
        assertEq(ReservoirLibrary.getPrecisionMultiplier(address(_tokenA)), 1);
        assertEq(ReservoirLibrary.getPrecisionMultiplier(address(_tokenD)), 1e12);
        assertEq(ReservoirLibrary.getPrecisionMultiplier(address(l0DecimalToken)), 1e18);
    }

    // commented out as vm.expectRevert does not work properly on library functions
    function testGetPrecisionMultiplier_MoreThan18Decimals() public {
        // act & assert
        vm.expectRevert(stdError.arithmeticError);
        lReservoirLib.getPrecisionMultiplier(address(_tokenE));
    }

    function testQuote_AmountZero() public {
        // arrange
        uint256 lAmountA = 0;

        // act & assert
        vm.expectRevert("RL: INSUFFICIENT_AMOUNT");
        ReservoirLibrary.quote(lAmountA, 1, 2);
    }

    function testQuote_ReserveZero() public {
        // act & assert
        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.quote(40, 0, 0);
    }

    function testQuote_Balanced(uint256 aReserveA, uint256 aAmountA) public {
        // assume
        uint256 lReserveA = bound(aReserveA, 1, type(uint112).max);
        uint256 lReserveB = lReserveA;
        uint256 lAmountA = bound(aAmountA, 1, type(uint112).max);

        // act
        uint256 lAmountB = ReservoirLibrary.quote(lAmountA, lReserveA, lReserveB);

        // assert
        assertEq(lAmountB, lAmountA);
    }

    function testQuote_Unbalanced(uint256 aReserveA, uint256 aReserveB, uint256 aAmountA) public {
        // assume
        uint256 lReserveA = bound(aReserveA, 1, type(uint112).max);
        uint256 lReserveB = bound(aReserveB, 1, type(uint112).max);
        uint256 lAmountA = bound(aAmountA, 1, type(uint112).max);

        // act
        uint256 lAmountB = ReservoirLibrary.quote(lAmountA, lReserveA, lReserveB);

        // assert
        assertEq(lAmountB, lAmountA * lReserveB / lReserveA);
    }

    function testGetAmountOut_InsufficientLiquidity(uint256 aAmountIn) public {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max);

        // act & assert
        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountOutStable(lAmountIn, 0, 0, 0, ExtraData(0, 0, 0));

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountOutConstantProduct(lAmountIn, 0, 0, 0);
    }

    function testGetAmountOut_InsufficientInputAmount() public {
        // act & revert
        vm.expectRevert("RL: INSUFFICIENT_INPUT_AMOUNT");
        ReservoirLibrary.getAmountOutStable(0, 10, 10, 30, ExtraData(0, 0, 0));

        vm.expectRevert("RL: INSUFFICIENT_INPUT_AMOUNT");
        ReservoirLibrary.getAmountOutConstantProduct(0, 10, 10, 30);
    }

    function testGetAmountOutConstantProduct(uint256 aAmountIn) public {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max - INITIAL_MINT_AMOUNT);

        // arrange
        (uint112 lReserve0, uint112 lReserve1,,) = _constantProductPair.getReserves();
        _tokenA.mint(address(_constantProductPair), lAmountIn);
        uint256 lSwapFee = _constantProductPair.swapFee();

        // act
        uint256 lAmountOut = ReservoirLibrary.getAmountOutConstantProduct(lAmountIn, lReserve0, lReserve1, lSwapFee);
        uint256 lActualAmountOut = _constantProductPair.swap(int256(lAmountIn), true, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountOutStable(uint256 aAmountIn) public {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max - INITIAL_MINT_AMOUNT);

        // arrange
        (uint112 lReserve0, uint112 lReserve1,,) = _stablePair.getReserves();
        _tokenA.mint(address(_stablePair), lAmountIn);
        uint256 lSwapFee = _stablePair.swapFee();
        uint64 lToken0PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token0());
        uint64 lToken1PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token1());
        uint64 lA = ReservoirLibrary.getAmplificationCoefficient(address(_stablePair));

        // act
        uint256 lAmountOut = ReservoirLibrary.getAmountOutStable(
            lAmountIn,
            lReserve0,
            lReserve1,
            lSwapFee,
            ExtraData(lToken0PrecisionMultiplier, lToken1PrecisionMultiplier, lA)
        );
        uint256 lActualAmountOut = _stablePair.swap(int256(lAmountIn), true, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountIn_InsufficientLiquidity(uint256 aAmountOut) public {
        // assume
        uint256 lAmountOut = bound(aAmountOut, 1, type(uint112).max);

        // act & assert
        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountInConstantProduct(lAmountOut, 0, 0, 0);

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountInStable(lAmountOut, 0, 0, 0, ExtraData(0, 0, 0));
    }

    function testGetAmountIn_InsufficientOutputAmount() public {
        // act & revert
        vm.expectRevert("RL: INSUFFICIENT_OUTPUT_AMOUNT");
        ReservoirLibrary.getAmountInConstantProduct(0, 10, 10, 30);

        vm.expectRevert("RL: INSUFFICIENT_OUTPUT_AMOUNT");
        ReservoirLibrary.getAmountInStable(0, 10, 10, 30, ExtraData(0, 0, 0));
    }

    function testGetAmountInConstantProduct(uint256 aAmountOut) public {
        // assume
        (uint112 lReserve0, uint112 lReserve1,,) = _constantProductPair.getReserves();
        uint256 lAmountOut = bound(aAmountOut, 1000, lReserve1 / 2);

        // arrange
        uint256 lSwapFee = _constantProductPair.swapFee();

        // act
        uint256 lAmountIn = ReservoirLibrary.getAmountInConstantProduct(lAmountOut, lReserve0, lReserve1, lSwapFee);
        _tokenA.mint(address(_constantProductPair), lAmountIn);
        uint256 lActualAmountOut = _constantProductPair.swap(-int256(lAmountOut), false, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountInStable(uint256 aAmountOut) public {
        // assume
        (uint112 lReserve0, uint112 lReserve1,,) = _stablePair.getReserves();
        uint256 lAmountOut = bound(aAmountOut, 1, lReserve1 / 2);

        // arrange
        uint256 lSwapFee = _stablePair.swapFee();
        uint64 lToken0PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token0());
        uint64 lToken1PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token1());
        uint64 lA = ReservoirLibrary.getAmplificationCoefficient(address(_stablePair));

        // act
        uint256 lAmountIn = ReservoirLibrary.getAmountInStable(
            lAmountOut,
            lReserve0,
            lReserve1,
            lSwapFee,
            ExtraData(lToken0PrecisionMultiplier, lToken1PrecisionMultiplier, lA)
        );
        _tokenA.mint(address(_stablePair), lAmountIn);
        uint256 lActualAmountOut = _stablePair.swap(-int256(lAmountOut), false, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountsOut_CP() public {
        // assume
        uint256 lAmtBToMint = 1000e18;
        uint256 lAmtCToMint = 10_000_000e18;
        uint256 lAmtIn = 49_382e18;

        // arrange
        ConstantProductPair lOtherPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
        _tokenB.mint(address(lOtherPair), lAmtBToMint);
        _tokenC.mint(address(lOtherPair), lAmtCToMint);
        lOtherPair.mint(address(this));

        // act
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[0], lAmtIn);
        assertEq(lAmounts[1], 99_797_299_436_610_000_102);
        assertEq(lAmounts[2], 904_939_489_708_253_368_940_016);
    }

    function testGetAmountsOut_SP() public {
        // assume
        uint256 lAmtBToMint = 12_392_592e18;
        uint256 lAmtCToMint = 6_391_019e18;
        uint256 lAmtIn = 49_382e18;

        // arrange
        StablePair lOtherPair = StablePair(_createPair(address(_tokenB), address(_tokenC), 1));
        _tokenB.mint(address(lOtherPair), lAmtBToMint);
        _tokenC.mint(address(lOtherPair), lAmtCToMint);
        lOtherPair.mint(address(this));

        // act
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 1;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[0], lAmtIn);
        assertEq(lAmounts[1], 99_999_999_589_842_730_809);
        assertEq(lAmounts[2], 99_910_889_683_691_058_630);
    }

    function testGetAmountsOut_MixedCurves() public {
        // assume
        uint256 lAmtBToMint = 10_000_000e18;
        uint256 lAmtCToMint = 1000e18;
        uint256 lAmtIn = 500e18;

        // arrange
        ConstantProductPair lOtherPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
        _tokenB.mint(address(lOtherPair), lAmtBToMint);
        _tokenC.mint(address(lOtherPair), lAmtCToMint);
        lOtherPair.mint(address(this));

        // act
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 0;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[0], lAmtIn);
        assertEq(lAmounts[lAmounts.length - 1], 9_969_485_213_337_276);
    }

    function testGetAmountsIn_CP() public {
        // arrange
        uint256 lAmtOut = 20e18;
        ConstantProductPair lOtherPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
        _tokenB.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        _tokenC.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        lOtherPair.mint(address(this));

        // act
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[0], 33_567_905_859_479_375_208);
        assertEq(lAmounts[1], 25_075_225_677_031_093_280);
        assertEq(lAmounts[2], lAmtOut);
    }

    // cannot use fuzz for mint amounts for new pair because the intermediate amountOuts might exceed the reserve of the next pair
    function testGetAmountsIn_SP(uint256 aAmtOut) public {
        // assume
        // limiting the max to INITIAL_MINT_AMOUNT / 2 for now as
        // having a large number will cause intermediate amounts to exceed reserves
        uint256 lAmtOut = bound(aAmtOut, 1e3, INITIAL_MINT_AMOUNT / 2);

        // arrange
        StablePair lOtherPair = StablePair(_createPair(address(_tokenB), address(_tokenC), 1));
        _tokenB.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        _tokenC.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        lOtherPair.mint(address(this));

        // act
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 1;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[2], lAmtOut);
        assertGt(lAmounts[0], lAmtOut);
    }

    function testGetAmountsIn_MixedCurves() public {
        // arrange
        testGetAmountsIn_CP();
        uint256 lAmtOut = 39e18;

        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 0;

        // act
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[0], 64_202_998_226_586_087_058);
        assertEq(lAmounts[1], 64_126_806_649_456_566_421);
        assertEq(lAmounts[2], lAmtOut);
    }
}
