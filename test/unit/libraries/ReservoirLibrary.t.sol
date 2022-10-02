pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { ExtraData } from "src/interfaces/IReservoirRouter.sol";

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";

contract ReservoirLibraryTest is BaseTest
{
    function testGetAmountOut_ErrorChecking(uint256 aAmountIn) public
    {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max);

        // act & revert
        vm.expectRevert("RL: INSUFFICIENT_INPUT_AMOUNT");
        ReservoirLibrary.getAmountOutStable(0, 10, 10, 30, ExtraData(0,0,0));

        vm.expectRevert("RL: INSUFFICIENT_INPUT_AMOUNT");
        ReservoirLibrary.getAmountOutConstantProduct(0, 10, 10, 30);

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountOutStable(lAmountIn, 0, 0, 0, ExtraData(0,0,0));

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountOutConstantProduct(lAmountIn, 0, 0, 0);
    }

    function testGetAmountOutConstantProduct(uint256 aAmountIn) public
    {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max);

        // arrange
        (uint112 lReserve0, uint112 lReserve1, ) = _constantProductPair.getReserves();
        _tokenA.mint(address(_constantProductPair), lAmountIn);
        uint256 lSwapFee = _constantProductPair.swapFee();

        // act
        uint256 lAmountOut = ReservoirLibrary.getAmountOutConstantProduct(lAmountIn, lReserve0, lReserve1, lSwapFee);
        uint256 lActualAmountOut = _constantProductPair.swap(int256(lAmountIn), true, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountOutStable(uint256 aAmountIn) public
    {
        // assume
        uint256 lAmountIn = bound(aAmountIn, 1, type(uint112).max);

        // arrange
        (uint112 lReserve0, uint112 lReserve1, ) = _stablePair.getReserves();
        _tokenA.mint(address(_stablePair), lAmountIn);
        uint256 lSwapFee = _stablePair.swapFee();
        uint64 lToken0PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token0());
        uint64 lToken1PrecisionMultiplier = ReservoirLibrary.getPrecisionMultiplier(_stablePair.token1());
        uint64 lA = ReservoirLibrary.getAmplificationCoefficient(address(_stablePair));

        // act
        uint256 lAmountOut
        = ReservoirLibrary.getAmountOutStable(
            lAmountIn,
            lReserve0,
            lReserve1,
            lSwapFee,
            ExtraData(lToken0PrecisionMultiplier,lToken1PrecisionMultiplier, lA)
        );
        uint256 lActualAmountOut = _stablePair.swap(int256(lAmountIn), true, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountIn_ErrorChecking(uint256 aCurveId, uint256 aAmountOut) public
    {
        // assume
        uint256 aAmountOut = bound(aAmountOut, 1, type(uint112).max);

        // act & revert
        vm.expectRevert("RL: INSUFFICIENT_OUTPUT_AMOUNT");
        ReservoirLibrary.getAmountInConstantProduct(0, 10, 10, 30);

        vm.expectRevert("RL: INSUFFICIENT_OUTPUT_AMOUNT");
        ReservoirLibrary.getAmountInStable(0, 10, 10, 30, ExtraData(0,0,0));

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountInConstantProduct(aAmountOut, 0, 0, 0);

        vm.expectRevert("RL: INSUFFICIENT_LIQUIDITY");
        ReservoirLibrary.getAmountInStable(aAmountOut, 0, 0, 0, ExtraData(0,0,0));
    }

    function testGetAmountInConstantProduct(uint256 aAmountOut) public
    {
        // assume
        (uint112 lReserve0, uint112 lReserve1, ) = _constantProductPair.getReserves();
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

    function testGetAmountInStable(uint256 aAmountOut) public
    {
        // assume
        (uint112 lReserve0, uint112 lReserve1, ) = _stablePair.getReserves();
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
            ExtraData(lToken0PrecisionMultiplier,lToken1PrecisionMultiplier, lA)
        );
        _tokenA.mint(address(_stablePair), lAmountIn);
        uint256 lActualAmountOut = _stablePair.swap(-int256(lAmountOut), false, address(this), bytes(""));

        // assert
        assertLt(lAmountOut, lAmountIn);
        assertEq(lAmountOut, lActualAmountOut);
    }

    function testGetAmountsOut_CP(uint256 aAmtBToMint, uint256 aAmtCToMint, uint256 aAmtIn) public
    {
        // assume
        uint256 lAmtBToMint = bound(aAmtBToMint, 2e3, type(uint112).max / 2);
        uint256 lAmtCToMint = bound(aAmtCToMint, 2e3, type(uint112).max / 2);
        uint256 lAmtIn = bound(aAmtIn, 2e3, type(uint112).max / 2);

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

    }

    function testGetAmountsOut_SP() public
    {

    }

    function testGetAmountsOut_MixCurves(uint256 aAmtBToMint, uint256 aAmtCToMint, uint256 aAmtIn) public
    {
        // assume
        uint256 lAmtBToMint = bound(aAmtBToMint, 2e3, type(uint112).max / 2);
        uint256 lAmtCToMint = bound(aAmtCToMint, 2e3, type(uint112).max / 2);
        uint256 lAmtIn = bound(aAmtIn, 2e3, type(uint112).max / 2);

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

    }

    function testGetAmountsIn_CP() public
    {

    }

    // cannot use fuzz for mint amounts for new pair because the intermediate amountOuts might exceed the reserve of the next pair
    function testGetAmountsIn_SP(uint256 aAmtOut) public
    {
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

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory),lAmtOut, lPath, lCurveIds);

        // assert
        assertEq(lAmounts[2], lAmtOut);
        assertGt(lAmounts[0], lAmtOut);
    }
}
