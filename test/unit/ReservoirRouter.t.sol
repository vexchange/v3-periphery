pragma solidity 0.8.13;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";

import { MathUtils } from "v3-core/src/libraries/MathUtils.sol";

import { ReservoirLibrary, IGenericFactory } from "src/libraries/ReservoirLibrary.sol";
import { ReservoirRouter } from "src/ReservoirRouter.sol";

contract ReservoirRouterTest is BaseTest
{
    WETH            private _weth   = new WETH();
    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(_weth));

    bytes[]         private _data;

    function testAddLiquidity(uint256 aTokenAMintAmt, uint256 aTokenBMintAmt) public
    {
        // arrange
        uint256 lTokenAMintAmt = bound(aTokenAMintAmt, 1, type(uint112).max);
        uint256 lTokenBMintAmt = bound(aTokenBMintAmt, 1, type(uint112).max);
        _tokenA.mint(_bob, lTokenAMintAmt);
        _tokenB.mint(_bob, lTokenBMintAmt);

        vm.startPrank(_bob);
        _tokenA.approve(address(_router), type(uint256).max);
        _tokenB.approve(address(_router), type(uint256).max);

        // act
        bytes[] memory lData = new bytes[](1);
        lData[0] = abi.encodeCall(
            _router.addLiquidity,
            (
                address(_tokenA),
                address(_tokenB),
                0,
                lTokenAMintAmt,
                lTokenBMintAmt,
                1,
                1,
                _bob
            )
        );

        bytes[] memory lResult = _router.multicall(lData);

        // assert
        ReservoirPair lPair = ReservoirPair(
                                ReservoirLibrary.pairFor(
                                    IGenericFactory(address(_factory)),
                                    address(_tokenA),
                                    address(_tokenB),
                                    0
                                ));
        (uint256 lAmountA, uint256 lAmountB, uint256 lLiquidity) = abi.decode(lResult[0], (uint256, uint256, uint256));
        assertEq(lLiquidity, FixedPointMathLib.sqrt(lAmountA * lAmountB));
        assertEq(lPair.balanceOf(_bob), lLiquidity);
        assertEq(_tokenA.balanceOf(_bob), lTokenAMintAmt - lAmountA);
        assertEq(_tokenB.balanceOf(_bob), lTokenBMintAmt - lAmountB);
        assertEq(_tokenA.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountA);
        assertEq(_tokenB.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountB);
    }

    function testAddLiquidity_CreatePair_ConstantProduct() public
    {
        // arrange
        uint256 lTokenAMintAmt = 5000e18;
        uint256 lTokenCMintAmt = 1000e18;
        _tokenA.mint(_bob, lTokenAMintAmt);
        _tokenC.mint(_bob, lTokenCMintAmt);
        vm.startPrank(_bob);
        _tokenA.approve(address(_router), type(uint256).max);
        _tokenC.approve(address(_router), type(uint256).max);

        // sanity
        assertEq(_tokenA.allowance(_bob, address(_router)), type(uint256).max);
        assertEq(_tokenC.allowance(_bob, address(_router)), type(uint256).max);

        // act
        (uint256 lAmountA, uint256 lAmountB, uint256 lLiquidity)
            = _router.addLiquidity(address(_tokenA), address(_tokenC), 0, lTokenAMintAmt, lTokenCMintAmt, 500e18, 500e18, _bob);

        // assert
        ReservoirPair lPair = ReservoirPair(_factory.getPair(address(_tokenC), address(_tokenA), 0));
        assertEq(lLiquidity, FixedPointMathLib.sqrt(lTokenAMintAmt * lTokenCMintAmt) - lPair.MINIMUM_LIQUIDITY());
        assertEq(lPair.balanceOf(_bob), lLiquidity);
        assertEq(_tokenA.balanceOf(_bob), 0);
        assertEq(_tokenC.balanceOf(_bob), 0);
        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt);
        assertEq(_tokenC.balanceOf(address(lPair)), lTokenCMintAmt);
    }

    function testAddLiquidity_CreatePair_ConstantProduct_Native() public
    {
        // arrange
        uint256 lTokenAMintAmt = 5000e18;
        uint256 lEthMintAmt = 5 ether;
        _tokenA.mint(_bob, lTokenAMintAmt);
        deal(_bob, 10 ether);
        vm.startPrank(_bob);
        _tokenA.approve(address(_router), type(uint256).max);
        _weth.approve(address(_router), type(uint256).max);

        // act
        bytes[] memory lData = new bytes[](2);
        lData[0] = abi.encodeCall(_router.wrapETH, (_bob, 5 ether));
        lData[1] = abi.encodeCall(
            _router.addLiquidity,
            (
                address(_weth),
                address(_tokenA),
                0,
                5 ether,
                lTokenAMintAmt,
                1e18,
                1e18,
                _bob
            )
        );

        bytes[] memory lResult = _router.multicall{value: 5 ether}(lData);

        // assert
        ReservoirPair lPair = ReservoirPair(_factory.getPair(address(_weth), address(_tokenA), 0));
        (uint256 lAmountA, uint256 lAmountB, uint256 lLiquidity) = abi.decode(lResult[1], (uint256, uint256, uint256));
        assertEq(lLiquidity, FixedPointMathLib.sqrt(lTokenAMintAmt * lEthMintAmt) - lPair.MINIMUM_LIQUIDITY());
        assertEq(lPair.balanceOf(_bob), lLiquidity);
        assertEq(_tokenA.balanceOf(_bob), 0);
        assertEq(_weth.balanceOf(_bob), 0);
        assertEq(_bob.balance, 5 ether);
        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt);
        assertEq(_weth.balanceOf(address(lPair)), lEthMintAmt);
    }

    function testRemoveLiquidity(uint256 aAmountToRemove) public
    {
        // arrange
        uint256 lStartingBalance = _constantProductPair.balanceOf(_alice);
        uint256 lAmountToRemove = bound(aAmountToRemove, 1, lStartingBalance);
        vm.startPrank(_alice);
        _constantProductPair.approve(address(_router), lAmountToRemove);

        // act
        bytes[] memory lData = new bytes[](1);
        lData[0] = abi.encodeCall(
            _router.removeLiquidity,
            (
                address(_tokenA),
                address(_tokenB),
                0,
                lAmountToRemove,
                1,
                1,
                address(_alice)
            )
        );

        bytes[] memory lResult = _router.multicall(lData);

        // assert
        (uint256 lAmountA, uint256 lAmountB) = abi.decode(lResult[0], (uint256, uint256));
        assertEq(_constantProductPair.balanceOf(_alice), lStartingBalance - lAmountToRemove);
        assertEq(_tokenA.balanceOf(_alice), lAmountA);
        assertEq(_tokenB.balanceOf(_alice), lAmountB);
    }

    function testRemoveLiquidity_Native() public
    {
        // arrange
        testAddLiquidity_CreatePair_ConstantProduct_Native();

        // act
//        _data.push(abi.encodeCall(
//            _router.unwrapWETH,
//            (
//                lAmount,
//                address(this)
//            )
//        ));

        // assert
    }

    function testQuoteAddLiquidity(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public
    {
        // arrange
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq)
            = _router.quoteAddLiquidity(address(_tokenA), address(_tokenB), 0, lAmountAToAdd, lAmountBToAdd);

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);

        assertEq(lLiq, FixedPointMathLib.sqrt(lAmountAOptimal * lAmountBOptimal));
    }

    function testQuoteAddLiquidity_Stable(uint256 aAmountAToAdd, uint256 aAmountBToAdd) public
    {
        // arrange
        uint256 lAmountAToAdd = bound(aAmountAToAdd, 1000, type(uint112).max);
        uint256 lAmountBToAdd = bound(aAmountBToAdd, 1000, type(uint112).max);

        // act
        (uint256 lAmountAOptimal, uint256 lAmountBOptimal, uint256 lLiq)
            = _router.quoteAddLiquidity(address(_tokenA), address(_tokenB), 1, lAmountAToAdd, lAmountBToAdd);

        // assert
        assertEq(lAmountAOptimal, Math.min(lAmountAToAdd, lAmountBToAdd));
        assertEq(lAmountBOptimal, lAmountAOptimal);
        assertEq(lLiq, lAmountAOptimal + lAmountBOptimal);
    }

    function testQuoteRemoveLiquidity(uint256 aLiquidity) public
    {
        // arrange
        uint256 lLiquidity = bound(aLiquidity, 1, _constantProductPair.balanceOf(_alice));

        // act
        (uint256 lAmountA, uint256 lAmountB) = _router.quoteRemoveLiquidity(address(_tokenA), address(_tokenB), 0, lLiquidity);
        testRemoveLiquidity(lLiquidity);

        // assert
        assertTrue(MathUtils.within1(lAmountA, _tokenA.balanceOf(_alice)));
    }

    function testCheckDeadline(uint256 aDeadline) public
    {
        // arrange
        uint256 lDeadline = bound(aDeadline, 1, type(uint64).max);
        uint256 lTimeToJump = bound(aDeadline, 0, lDeadline - 1);
        _stepTime(lTimeToJump);
        _data.push(abi.encodeCall(_router.checkDeadline, (lDeadline)));

        // act
        _router.multicall(_data);
    }

    function testCheckDeadline_PastDeadline(uint256 aDeadline) public
    {
        // arrange
        uint256 lTimeToJump = bound(aDeadline, 1, type(uint64).max);
        uint256 lDeadline = bound(aDeadline, 1, lTimeToJump);
        _stepTime(lTimeToJump);
        _data.push(abi.encodeCall(_router.checkDeadline, (lDeadline)));

        // act & assert
        vm.expectRevert("PH: TX_TOO_OLD");
        _router.multicall(_data);
    }
}
