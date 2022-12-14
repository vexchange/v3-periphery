pragma solidity ^0.8.0;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { ReservoirRouter } from "src/ReservoirRouter.sol";

contract SelfPermitTest is BaseTest {

    WETH            private _weth   = new WETH();
    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(_weth));

    function _getPermitSignature() private returns (uint8, bytes32, bytes32)
    {
        return(0, bytes32(0), bytes32(0));
    }

    function testPermit() external
    {
        // arrange
        uint256 lValue = 595959; // make fuzzed later
        (uint8 lV, bytes32 lR, bytes32 lS) = _getPermitSignature();

        // sanity
        // allowance at the beginning is zero


        // act

        // assert

    }


    function testSelfPermit() external
    {

    }

    function testSelfPermitIfNecessary() external
    {

    }
}
