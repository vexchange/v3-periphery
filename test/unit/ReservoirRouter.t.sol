pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Math } from "@openzeppelin/utils/math/Math.sol";

import { MathUtils } from "v3-core/src/libraries/MathUtils.sol";

import { ReservoirLibrary, IGenericFactory } from "src/libraries/ReservoirLibrary.sol";
import { ReservoirRouter } from "src/ReservoirRouter.sol";

contract ReservoirRouterTest is BaseTest {
    using FixedPointMathLib for uint256;

    WETH private _weth = new WETH();
    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(_weth));

    bytes[] private _data;

    // required to receive ETH refunds from the router
    receive() external payable { } // solhint-disable-line no-empty-blocks

//    function testAddLiquidity_CP(uint256 aTokenAMintAmt, uint256 aTokenBMintAmt) public {
//        // assume
//        uint256 lTokenAMintAmt = bound(aTokenAMintAmt, 1, type(uint112).max - INITIAL_MINT_AMOUNT);
//        uint256 lTokenBMintAmt = bound(aTokenBMintAmt, 1, type(uint112).max - INITIAL_MINT_AMOUNT);
//
//        // arrange
//        _tokenA.mint(_bob, lTokenAMintAmt);
//        _tokenB.mint(_bob, lTokenBMintAmt);
//
//        vm.startPrank(_bob);
//        _tokenA.approve(address(_router), type(uint256).max);
//        _tokenB.approve(address(_router), type(uint256).max);
//
//        // act
//        _data.push(
//            abi.encodeCall(
//                _router.addLiquidity,
//                (address(_tokenA), address(_tokenB), 0, lTokenAMintAmt, lTokenBMintAmt, 1, 1, _bob)
//            )
//        );
//
//        bytes[] memory lResult = _router.multicall(_data);
//
//        // assert
//        ReservoirPair lPair =
//            ReservoirPair(ReservoirLibrary.pairFor(address(_factory), address(_tokenA), address(_tokenB), 0));
//        (uint256 lAmountA, uint256 lAmountB, uint256 lLiquidity) = abi.decode(lResult[0], (uint256, uint256, uint256));
//        assertEq(lLiquidity, FixedPointMathLib.sqrt(lAmountA * lAmountB));
//        assertEq(lPair.balanceOf(_bob), lLiquidity);
//        assertEq(_tokenA.balanceOf(_bob), lTokenAMintAmt - lAmountA);
//        assertEq(_tokenB.balanceOf(_bob), lTokenBMintAmt - lAmountB);
//        assertEq(_tokenA.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountA);
//        assertEq(_tokenB.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountB);
//    }

    function testAddLiquidity_CreatePair_CP() public {
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
        (,, uint256 lLiquidity) = _router.addLiquidity(
            address(_tokenA), address(_tokenC), 0, lTokenAMintAmt, lTokenCMintAmt, 500e18, 500e18, _bob
        );

        // assert
        ReservoirPair lPair = ReservoirPair(_factory.getPair(address(_tokenC), address(_tokenA), 0));
        assertEq(lLiquidity, FixedPointMathLib.sqrt(lTokenAMintAmt * lTokenCMintAmt) - lPair.MINIMUM_LIQUIDITY());
        assertEq(lPair.balanceOf(_bob), lLiquidity);
        assertEq(_tokenA.balanceOf(_bob), 0);
        assertEq(_tokenC.balanceOf(_bob), 0);
        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt);
        assertEq(_tokenC.balanceOf(address(lPair)), lTokenCMintAmt);
    }

    function testAddLiquidity_CreatePair_CP_Native() public {
        // arrange
        uint256 lTokenAMintAmt = 5000e18;
        uint256 lEthMintAmt = 5 ether;
        _tokenA.mint(_bob, lTokenAMintAmt);
        deal(_bob, 10 ether);
        vm.startPrank(_bob);
        _tokenA.approve(address(_router), type(uint256).max);

        // act
        _data.push(
            abi.encodeCall(
                _router.addLiquidity, (address(_weth), address(_tokenA), 0, 5 ether, lTokenAMintAmt, 1e18, 1e18, _bob)
            )
        );
        _data.push(abi.encodeCall(_router.refundETH, ()));

        // send more ether than needed to see if ETH is refunded
        bytes[] memory lResult = _router.multicall{value: 8 ether}(_data);

        // assert
        ReservoirPair lPair = ReservoirPair(_factory.getPair(address(_weth), address(_tokenA), 0));
        (,, uint256 lLiquidity) = abi.decode(lResult[0], (uint256, uint256, uint256));
        assertEq(lLiquidity, FixedPointMathLib.sqrt(lTokenAMintAmt * lEthMintAmt) - lPair.MINIMUM_LIQUIDITY());
        assertEq(lPair.balanceOf(_bob), lLiquidity);
        assertEq(_tokenA.balanceOf(_bob), 0);
        assertEq(_weth.balanceOf(_bob), 0);
        assertEq(_bob.balance, 5 ether);
        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt);
        assertEq(_weth.balanceOf(address(lPair)), lEthMintAmt);
    }

//    function testAddLiquidity_SP_Balanced(uint256 aTokenAMintAmt, uint256 aTokenBMintAmt) public {
//        // assume
//        uint256 lTokenAMintAmt = bound(aTokenAMintAmt, 1, type(uint112).max - INITIAL_MINT_AMOUNT);
//        uint256 lTokenBMintAmt = bound(aTokenBMintAmt, 1, type(uint112).max - INITIAL_MINT_AMOUNT);
//
//        // arrange
//        _tokenA.mint(_bob, lTokenAMintAmt);
//        _tokenB.mint(_bob, lTokenBMintAmt);
//
//        vm.startPrank(_bob);
//        _tokenA.approve(address(_router), type(uint256).max);
//        _tokenB.approve(address(_router), type(uint256).max);
//
//        // act
//        _data.push(
//            abi.encodeCall(
//                _router.addLiquidity,
//                (address(_tokenA), address(_tokenB), 1, lTokenAMintAmt, lTokenBMintAmt, 1, 1, _bob)
//            )
//        );
//
//        bytes[] memory lResult = _router.multicall(_data);
//
//        // assert
//        ReservoirPair lPair =
//            ReservoirPair(ReservoirLibrary.pairFor(address(_factory), address(_tokenA), address(_tokenB), 1));
//        (uint256 lAmountA, uint256 lAmountB, uint256 lLiquidity) = abi.decode(lResult[0], (uint256, uint256, uint256));
//        assertEq(lPair.balanceOf(_bob), lLiquidity);
//        assertEq(_tokenA.balanceOf(_bob), lTokenAMintAmt - lAmountA);
//        assertEq(_tokenB.balanceOf(_bob), lTokenBMintAmt - lAmountB);
//        assertEq(_tokenA.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountA);
//        assertEq(_tokenB.balanceOf(address(lPair)), INITIAL_MINT_AMOUNT + lAmountB);
//        assertEq(lLiquidity, lAmountA + lAmountB);
//    }

//    function testAddLiquidity_SP_Unbalanced(
//        uint256 aTokenAMintAmt,
//        uint256 aTokenCMintAmt,
//        uint256 aTokenAToAdd,
//        uint256 aTokenCToAdd
//    ) public {
//        // assume
//        uint256 lTokenAMintAmt = bound(aTokenAMintAmt, 10_000_000e18, 20_000_000e18);
//        uint256 lTokenCMintAmt = bound(aTokenCMintAmt, 25_000_000e18, 80_000_000e18);
//        uint256 lTokenAToAdd = bound(aTokenAToAdd, 1e6, type(uint112).max - lTokenAMintAmt);
//        uint256 lTokenCToAdd = bound(aTokenCToAdd, 1e6, type(uint112).max - lTokenCMintAmt);
//
//        // arrange
//        StablePair lPair = StablePair(_createPair(address(_tokenA), address(_tokenC), 1));
//        _tokenA.mint(address(lPair), lTokenAMintAmt);
//        _tokenC.mint(address(lPair), lTokenCMintAmt);
//        lPair.mint(address(this));
//
//        _tokenA.mint(_bob, lTokenAToAdd);
//        _tokenC.mint(_bob, lTokenCToAdd);
//        vm.startPrank(_bob);
//        _tokenA.approve(address(_router), type(uint256).max);
//        _tokenC.approve(address(_router), type(uint256).max);
//
//        // act
//        _data.push(
//            abi.encodeCall(
//                _router.addLiquidity, (address(_tokenA), address(_tokenC), 1, lTokenAToAdd, lTokenCToAdd, 1, 1, _bob)
//            )
//        );
//
//        bytes[] memory lResult = _router.multicall(_data);
//
//        // assert
//        (uint256 lAmountA, uint256 lAmountC, uint256 lLiquidity) = abi.decode(lResult[0], (uint256, uint256, uint256));
//        assertEq(lPair.balanceOf(_bob), lLiquidity);
//
//        assertEq(_tokenA.balanceOf(_bob), lTokenAToAdd - lAmountA);
//        assertEq(_tokenC.balanceOf(_bob), lTokenCToAdd - lAmountC);
//        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt + lAmountA);
//        assertEq(_tokenC.balanceOf(address(lPair)), lTokenCMintAmt + lAmountC);
//        assertLt(lLiquidity, lAmountA + lAmountC);
//        // check that they are in the same proportions
//        assertApproxEqRel(lAmountA.divWadDown(lAmountC), lTokenAMintAmt.divWadDown(lTokenCMintAmt), 0.00001e18); // 0.1 bp
//    }

//    function testAddLiquidity_CreatePair_SP(uint256 aTokenAMintAmt, uint256 aTokenCMintAmt) public {
//        uint256 lTokenAMintAmt = bound(aTokenAMintAmt, 1e6, type(uint112).max);
//        uint256 lTokenCMintAmt =
//            bound(aTokenCMintAmt, lTokenAMintAmt / 1e3, Math.min(type(uint112).max, lTokenAMintAmt * 1e3));
//        _tokenA.mint(_bob, lTokenAMintAmt);
//        _tokenC.mint(_bob, lTokenCMintAmt);
//        vm.startPrank(_bob);
//        _tokenA.approve(address(_router), type(uint256).max);
//        _tokenC.approve(address(_router), type(uint256).max);
//
//        // sanity
//        assertEq(_tokenA.allowance(_bob, address(_router)), type(uint256).max);
//        assertEq(_tokenC.allowance(_bob, address(_router)), type(uint256).max);
//
//        // act
//        (uint256 lAmountA, uint256 lAmountC, uint256 lLiquidity) = _router.addLiquidity(
//            address(_tokenA), address(_tokenC), 1, lTokenAMintAmt, lTokenCMintAmt, 500e18, 500e18, _bob
//        );
//
//        // assert
//        ReservoirPair lPair = ReservoirPair(_factory.getPair(address(_tokenC), address(_tokenA), 1));
//        assertEq(lPair.balanceOf(_bob), lLiquidity);
//        assertEq(lAmountA, lTokenAMintAmt);
//        assertEq(lAmountC, lTokenCMintAmt);
//        assertEq(_tokenA.balanceOf(address(lPair)), lTokenAMintAmt);
//        assertEq(_tokenC.balanceOf(address(lPair)), lTokenCMintAmt);
//    }

    function testAddLiquidity_OptimalLessThanMin() public {
        // act & assert
        vm.expectRevert("RR: INSUFFICIENT_A_AMOUNT");
        _router.addLiquidity(address(_tokenA), address(_tokenB), 1, 101e18, 99e18, 100e18, 100e18, _bob);

        vm.expectRevert("RR: INSUFFICIENT_B_AMOUNT");
        _router.addLiquidity(address(_tokenA), address(_tokenB), 1, 99e18, 101e18, 100e18, 100e18, _bob);
    }

    function testRemoveLiquidity(uint256 aAmountToRemove) public {
        // assume
        uint256 lStartingBalance = _constantProductPair.balanceOf(_alice);
        uint256 lAmountToRemove = bound(aAmountToRemove, 1, lStartingBalance);

        // arrange
        vm.startPrank(_alice);
        _constantProductPair.approve(address(_router), lAmountToRemove);

        // act
        _data.push(
            abi.encodeCall(
                _router.removeLiquidity, (address(_tokenA), address(_tokenB), 0, lAmountToRemove, 1, 1, address(_alice))
            )
        );

        bytes[] memory lResult = _router.multicall(_data);

        // assert
        (uint256 lAmountA, uint256 lAmountB) = abi.decode(lResult[0], (uint256, uint256));
        assertEq(_constantProductPair.balanceOf(_alice), lStartingBalance - lAmountToRemove);
        assertEq(_tokenA.balanceOf(_alice), lAmountA);
        assertEq(_tokenB.balanceOf(_alice), lAmountB);
    }

    function testRemoveLiquidity_Native() public {
        // arrange
        testAddLiquidity_CreatePair_CP_Native();
        // clear data from previous test
        delete _data;
        ReservoirPair lPair =
            ReservoirPair(ReservoirLibrary.pairFor(address(_factory), address(_tokenA), address(_weth), 0));
        uint256 lLiq = lPair.balanceOf(_bob);
        lPair.approve(address(_router), lLiq);

        // act
        _data.push(
            abi.encodeCall(_router.removeLiquidity, (address(_tokenA), address(_weth), 0, lLiq, 1, 1, address(_router)))
        );
        _data.push(
            abi.encodeCall(
                _router.sweepToken,
                (
                    address(_tokenA),
                    500, // whatever
                    _bob
                )
            )
        );
        _data.push(
            abi.encodeCall(
                _router.unwrapWETH,
                (
                    5, // wtv
                    _bob
                )
            )
        );

        _router.multicall(_data);

        // assert
        assertEq(lPair.balanceOf(_bob), 0);
        assertEq(_tokenA.balanceOf(_bob), lLiq * 5000e18 / (lLiq + lPair.MINIMUM_LIQUIDITY()));
        assertEq(_bob.balance, 5 ether + lLiq * 5 ether / (lLiq + lPair.MINIMUM_LIQUIDITY()));
    }

    function testRemoveLiquidity_ReceivedLessThanMin() public {
        // arrange
        uint256 lAmountToBurn = 50e18;
        vm.startPrank(_alice);
        _stablePair.approve(address(_router), lAmountToBurn);

        // act & assert
        vm.expectRevert("RR: INSUFFICIENT_A_AMOUNT");
        _router.removeLiquidity(
            address(_tokenA), address(_tokenB), 1, lAmountToBurn, lAmountToBurn / 2 + 1, 0, address(this)
        );

        vm.expectRevert("RR: INSUFFICIENT_B_AMOUNT");
        _router.removeLiquidity(
            address(_tokenA), address(_tokenB), 1, lAmountToBurn, 0, lAmountToBurn / 2 + 1, address(this)
        );
    }

    function testCheckDeadline(uint256 aDeadline) public {
        // assume
        uint256 lDeadline = bound(aDeadline, 1, type(uint64).max);
        uint256 lTimeToJump = bound(aDeadline, 0, lDeadline - 1);

        // arrange
        _stepTime(lTimeToJump);
        _data.push(abi.encodeCall(_router.checkDeadline, (lDeadline)));

        // act
        _router.multicall(_data);
    }

    function testCheckDeadline_PastDeadline(uint256 aDeadline) public {
        // assume
        uint256 lTimeToJump = bound(aDeadline, 1, type(uint64).max);
        uint256 lDeadline = bound(aDeadline, 1, lTimeToJump);

        // arrange
        _stepTime(lTimeToJump);
        _data.push(abi.encodeCall(_router.checkDeadline, (lDeadline)));

        // act & assert
        vm.expectRevert("PH: TX_TOO_OLD");
        _router.multicall(_data);
    }

//    function testSwapExactForVariable(uint256 aAmtBToMint, uint256 aAmtCToMint, uint256 aAmtIn) public {
//        // arrange
//        uint256 lAmtBToMint = bound(aAmtBToMint, 2e3, type(uint112).max / 2);
//        uint256 lAmtCToMint = bound(aAmtCToMint, 2e3, type(uint112).max / 2);
//        uint256 lAmtIn = bound(aAmtIn, 2e3, type(uint112).max / 2);
//        ConstantProductPair lOtherPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
//        _tokenB.mint(address(lOtherPair), lAmtBToMint);
//        _tokenC.mint(address(lOtherPair), lAmtCToMint);
//        lOtherPair.mint(address(this));
//
//        address[] memory lPath = new address[](3);
//        lPath[0] = address(_tokenA);
//        lPath[1] = address(_tokenB);
//        lPath[2] = address(_tokenC);
//        uint256[] memory lCurveIds = new uint256[](2);
//        lCurveIds[0] = 0;
//        lCurveIds[1] = 0;
//        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);
//
//        uint256 lAmountOutMin = lAmounts[lAmounts.length - 1] * 99 / 100; // 1% slippage
//
//        _tokenA.mint(address(this), lAmtIn);
//        _tokenA.approve(address(_router), lAmtIn);
//
//        // act
//        _router.swapExactForVariable(lAmtIn, lAmountOutMin, lPath, lCurveIds, address(this));
//
//        // assert
//        assertEq(lAmounts[0], lAmtIn);
//        assertEq(_tokenA.balanceOf(address(this)), 0);
//        assertEq(_tokenC.balanceOf(address(this)), lAmounts[2]);
//    }

    function testSwapExactForVariable_Slippage() public {
        // arrange
        uint256 lAmtBToMint = 100e18;
        uint256 lAmtCToMint = 100e18;
        uint256 lAmtIn = 10e18;
        ConstantProductPair lOtherPair = ConstantProductPair(_createPair(address(_tokenB), address(_tokenC), 0));
        _tokenB.mint(address(lOtherPair), lAmtBToMint);
        _tokenC.mint(address(lOtherPair), lAmtCToMint);
        lOtherPair.mint(address(this));

        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);

        uint256 lAmountOutMin = lAmounts[lAmounts.length - 1] * 99 / 100; // 1% slippage

        _tokenA.mint(address(this), lAmtIn);
        _tokenA.approve(address(_router), lAmtIn);

        // bob frontruns the trade
        _tokenA.mint(address(_constantProductPair), lAmtIn);
        _constantProductPair.swap(int256(lAmtIn), true, _bob, bytes(""));

        // sanity
        assertGt(_tokenB.balanceOf(_bob), 0);

        // act & assert
        vm.expectRevert("RR: INSUFFICIENT_OUTPUT_AMOUNT");
        _router.swapExactForVariable(lAmtIn, lAmountOutMin, lPath, lCurveIds, address(this));
    }

    function testSwapExactForVariable_NativeIn() public {
        // arrange
        testAddLiquidity_CreatePair_CP_Native();
        delete _data;
        uint256 lAmtIn = 1e18;

        // ETH -> tokenA -> tokenB
        address[] memory lPath = new address[](3);
        lPath[0] = address(_weth);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_tokenB);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);
        uint256 lAmountOutMin = lAmounts[lAmounts.length - 1] * 99 / 100; // 1% slippage

        // act
        _data.push(
            abi.encodeCall(_router.swapExactForVariable, (lAmtIn, lAmountOutMin, lPath, lCurveIds, address(this)))
        );
        _data.push(abi.encodeCall(_router.refundETH, ()));

        bytes[] memory lResult = _router.multicall{value: lAmtIn}(_data);

        // assert
        uint256 lAmountOut = abi.decode(lResult[0], (uint256));
        assertEq(_tokenB.balanceOf(address(this)), lAmounts[lAmounts.length - 1]);
        assertEq(lAmountOut, lAmounts[lAmounts.length - 1]);
    }

    function testSwapExactForVariable_NativeOut() public {
        // arrange
        testAddLiquidity_CreatePair_CP_Native();
        delete _data;
        uint256 lAmtIn = 1e18;

        _tokenB.mint(address(_bob), lAmtIn);
        _tokenB.approve(address(_router), lAmtIn);

        // tokenB -> tokenA -> ETH
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenB);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_weth);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);
        uint256 lAmountOutMin = lAmounts[lAmounts.length - 1] * 99 / 100; // 1% slippage

        // act
        _data.push(
            abi.encodeCall(_router.swapExactForVariable, (lAmtIn, lAmountOutMin, lPath, lCurveIds, address(_router)))
        );
        _data.push(abi.encodeCall(_router.unwrapWETH, (lAmountOutMin, _cal)));

        bytes[] memory lResult = _router.multicall(_data);

        // assert
        uint256 lAmountOut = abi.decode(lResult[0], (uint256));
        assertEq(_cal.balance, lAmounts[lAmounts.length - 1]);
        assertEq(lAmountOut, _cal.balance);
    }

//    function testSwapExactForVariable_MixedCurves(uint256 aAmtIn) public {
//        // assume
//        uint256 lAmtIn = bound(aAmtIn, 1000, type(uint112).max / 2);
//
//        // arrange
//        testAddLiquidity_CreatePair_CP();
//        delete _data;
//        vm.stopPrank();
//
//        // tokenB -> tokenA -> tokenC
//        address[] memory lPath = new address[](3);
//        lPath[0] = address(_tokenB);
//        lPath[1] = address(_tokenA);
//        lPath[2] = address(_tokenC);
//        uint256[] memory lCurveIds = new uint256[](2);
//        lCurveIds[0] = 1;
//        lCurveIds[1] = 0;
//        uint256[] memory lAmounts = ReservoirLibrary.getAmountsOut(address(_factory), lAmtIn, lPath, lCurveIds);
//        uint256 lAmountOutMin = lAmounts[lAmounts.length - 1] * 99 / 100; // 1% slippage
//
//        _tokenB.mint(address(this), lAmtIn);
//        _tokenB.approve(address(_router), lAmtIn);
//
//        // act
//        _data.push(
//            abi.encodeCall(_router.swapExactForVariable, (lAmtIn, lAmountOutMin, lPath, lCurveIds, address(this)))
//        );
//
//        bytes[] memory lResult = _router.multicall(_data);
//
//        // assert
//        uint256 lAmountOut = abi.decode(lResult[0], (uint256));
//        assertEq(lAmountOut, lAmounts[lAmounts.length - 1]);
//        assertEq(lAmountOut, _tokenC.balanceOf(address(this)));
//    }

    function testSwapVariableForExact(uint256 aAmtOut) public {
        // arrange;
        StablePair lOtherPair = StablePair(_createPair(address(_tokenB), address(_tokenC), 1));
        _tokenB.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        _tokenC.mint(address(lOtherPair), INITIAL_MINT_AMOUNT);
        lOtherPair.mint(address(this));

        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenA);
        lPath[1] = address(_tokenB);
        lPath[2] = address(_tokenC);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 1;
        lCurveIds[1] = 1;

        uint256 lAmtOut = bound(aAmtOut, 1e3, INITIAL_MINT_AMOUNT / 2);

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);

        uint256 lAmountInMax = lAmounts[0] * 101 / 100; // 1% slippage

        _tokenA.mint(address(this), lAmounts[0]);
        _tokenA.approve(address(_router), lAmounts[0]);

        // act
        _router.swapVariableForExact(lAmtOut, lAmountInMax, lPath, lCurveIds, address(this));

        // assert
        assertEq(lAmounts[lAmounts.length - 1], lAmtOut);
        assertEq(_tokenA.balanceOf(address(this)), 0);
        assertEq(_tokenC.balanceOf(address(this)), lAmtOut);
    }

    function testSwapVariableForExact_NativeIn() public {
        // arrange
        testAddLiquidity_CreatePair_CP_Native();
        delete _data;
        uint256 lAmtOut = 1e18;

        // ETH -> tokenA -> tokenB
        address[] memory lPath = new address[](3);
        lPath[0] = address(_weth);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_tokenB);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);
        uint256 lAmountInMax = lAmounts[0] * 101 / 100; // 1% slippage

        _data.push(
            abi.encodeCall(_router.swapVariableForExact, (lAmtOut, lAmountInMax, lPath, lCurveIds, address(this)))
        );
        _data.push(abi.encodeCall(_router.refundETH, ()));
        bytes[] memory lResult = _router.multicall{value: lAmounts[0]}(_data);

        // assert
        uint256[] memory lAmountsReturned = abi.decode(lResult[0], (uint256[]));
        assertEq(_tokenB.balanceOf(address(this)), lAmtOut);
        assertEq(lAmountsReturned, lAmounts);
    }

    function testSwapVariableForExact_NativeIn_RefundETH() public {
        // arrange
        testAddLiquidity_CreatePair_CP_Native();
        delete _data;
        vm.stopPrank();
        uint256 lAmtOut = 1e18;
        uint256 lEtherToMint = 100 ether;
        deal(address(this), lEtherToMint);

        // ETH -> tokenA -> tokenB
        address[] memory lPath = new address[](3);
        lPath[0] = address(_weth);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_tokenB);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;

        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);
        uint256 lAmountInMax = lAmounts[0] * 101 / 100; // 1% slippage

        _data.push(
            abi.encodeCall(_router.swapVariableForExact, (lAmtOut, lAmountInMax, lPath, lCurveIds, address(this)))
        );
        _data.push(abi.encodeCall(_router.refundETH, ()));

        // send way too much ETH to the router
        _router.multicall{value: address(this).balance}(_data);

        // assert
        assertEq(address(this).balance, lEtherToMint - lAmounts[0]);
        assertEq(address(_router).balance, 0);
        assertEq(_tokenB.balanceOf(address(this)), lAmtOut);
    }

    function testSwapVariableForExact_NativeOut() public {
        testAddLiquidity_CreatePair_CP_Native();
        delete _data;
        vm.stopPrank();
        deal(address(this), 0);
        uint256 lAmtOut = 1e6;

        // tokenB -> tokenA -> ETH
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenB);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_weth);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 0;
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);
        uint256 lAmountInMax = lAmounts[0] * 101 / 100; // 1% slippage
        _tokenB.mint(address(this), lAmounts[0]);
        _tokenB.approve(address(_router), lAmounts[0]);

        // act
        _data.push(
            abi.encodeCall(_router.swapVariableForExact, (lAmtOut, lAmountInMax, lPath, lCurveIds, address(_router)))
        );
        _data.push(abi.encodeCall(_router.unwrapWETH, (lAmounts[lAmounts.length - 1], address(this))));

        bytes[] memory lResult = _router.multicall(_data);

        // assert
        uint256[] memory lActualAmounts = abi.decode(lResult[0], (uint256[]));
        assertEq(lActualAmounts, lAmounts);
        assertEq(address(this).balance, lAmtOut);
    }

    function testSwapVariableForExact_MixedCurves() public {
        // assume
        uint256 lAmtOut = 10e8;

        // arrange
        testAddLiquidity_CreatePair_CP();
        delete _data;
        vm.stopPrank();

        // tokenC -> tokenA -> tokenB
        address[] memory lPath = new address[](3);
        lPath[0] = address(_tokenC);
        lPath[1] = address(_tokenA);
        lPath[2] = address(_tokenB);
        uint256[] memory lCurveIds = new uint256[](2);
        lCurveIds[0] = 0;
        lCurveIds[1] = 1;
        uint256[] memory lAmounts = ReservoirLibrary.getAmountsIn(address(_factory), lAmtOut, lPath, lCurveIds);
        uint256 lAmountInMax = lAmounts[lAmounts.length - 1] * 101 / 100; // 1% slippage

        _tokenC.mint(address(this), lAmountInMax);
        _tokenC.approve(address(_router), lAmountInMax);

        // act
        _data.push(
            abi.encodeCall(_router.swapVariableForExact, (lAmtOut, lAmountInMax, lPath, lCurveIds, address(this)))
        );

        bytes[] memory lResult = _router.multicall(_data);

        // assert
        uint256[] memory lActualAmounts = abi.decode(lResult[0], (uint256[]));
        assertEq(lActualAmounts, lAmounts);
        assertGt(_tokenC.balanceOf(address(this)), 0);
    }
}
