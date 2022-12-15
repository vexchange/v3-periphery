pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { ReservoirRouter } from "src/ReservoirRouter.sol";
import { TestERC20PermitAllowed } from "test/dummy/TestERC20PermitAllowed.sol";

contract SelfPermitTest is BaseTest {

    WETH            private _weth   = new WETH();
    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(_weth));

    TestERC20PermitAllowed private _testERC20 = new TestERC20PermitAllowed(type(uint256).max);
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 private _ownerPrivateKey = 0x5555;
    address private _owner = vm.addr(_ownerPrivateKey);

    function setUp() public
    {
        _testERC20.transfer(_owner, _testERC20.balanceOf(address(this)));
    }

    function _getPermitSignature(
        TestERC20PermitAllowed aToken, address aSpender, uint256 aValue, uint256 aDeadline
    ) private returns (uint8 rV, bytes32 rR, bytes32 rS)
    {
        bytes32 lDigest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                aToken.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, _owner, aSpender, aValue, aToken.nonces(_owner), aDeadline))
            )
        );

        (rV, rR, rS) = vm.sign(_ownerPrivateKey, lDigest);
    }

    function testPermit(uint256 aValue) external
    {
        // assume
        uint256 lValue = bound(aValue, 1, type(uint256).max);

        // arrange
        uint256 lDeadline = block.timestamp + 100;
        (uint8 lV, bytes32 lR, bytes32 lS) = _getPermitSignature(_testERC20, _alice, lValue, lDeadline);

        // sanity - allowance at the beginning is zero
        assertEq(_testERC20.allowance(_owner, _alice), 0);

        // act
        _testERC20.permit(_owner, _alice, lValue, lDeadline, lV, lR, lS);

        // assert
        assertEq(_testERC20.allowance(_owner, _alice), lValue);
        assertEq(_testERC20.nonces(_owner), 1);
        vm.prank(_alice);
        _testERC20.transferFrom(_owner, _alice, lValue);
        assertEq(_testERC20.balanceOf(_alice), lValue);
    }

    function testSelfPermit(uint256 aValue) external
    {
        // assume
        uint256 lValue = bound(aValue, 1, type(uint256).max);

        // arrange
        uint256 lDeadline = block.timestamp + 100;
        (uint8 lV, bytes32 lR, bytes32 lS) = _getPermitSignature(_testERC20, address(_router), lValue, lDeadline);

        // act
        vm.prank(_owner);
        _router.selfPermit(address(_testERC20), lValue, lDeadline, lV, lR, lS);

        // assert
        assertEq(_testERC20.allowance(_owner, address(_router)), lValue);
    }

    function testSelfPermitIfNecessary_SufficientAllowanceNoAction(uint256 aValue) external
    {
        // assume
        uint256 lValue = bound(aValue, 1, type(uint256).max);

        // arrange
        uint256 lDeadline = block.timestamp + 100;
        vm.prank(_owner);
        _testERC20.approve(_alice, type(uint256).max);
        (uint8 lV, bytes32 lR, bytes32 lS) = _getPermitSignature(_testERC20, address(_router), lValue, lDeadline);

        // act
        vm.prank(_owner);
        _router.selfPermitIfNecessary(address(_testERC20), lValue, lDeadline, lV, lR, lS);

        // assert
        assertEq(_testERC20.allowance(_owner, _alice), type(uint256).max);
    }
}
