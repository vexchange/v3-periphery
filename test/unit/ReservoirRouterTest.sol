pragma solidity 0.8.13;

import "v3-core/test/__fixtures/BaseTest.sol";

import { WETH } from "solmate/tokens/WETH.sol";

import { ReservoirRouter } from "src/ReservoirRouter.sol";

contract ReservoirRouterTest is BaseTest {

    ReservoirRouter private _router = new ReservoirRouter(address(_factory), address(0));
    WETH            private _weth   = new WETH();

    function testHaha() external {

    }
}
