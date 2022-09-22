pragma solidity 0.8.13;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { ReservoirLibrary, IGenericFactory } from "src/libraries/ReservoirLibrary.sol";
import { ReservoirRouter } from "src/ReservoirRouter.sol";

contract ReservoirRouterTest is BaseTest
{
    WETH            private _weth   = new WETH();
    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(_weth));

    function testAddLiquidity(uint256 aTokenAMintAmt, uint256 aTokenBMintAmt) external
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

    function testAddLiquidity_CreatePair_ConstantProduct() external
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

    function testAddLiquidity_CreatePair_ConstantProduct_Native() external
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

    function testRemoveLiquidity(uint256 aAmountToRemove) external
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
}
