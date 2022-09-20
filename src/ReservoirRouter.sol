pragma solidity 0.8.17;

import { IReservoirRouter } from "src/interfaces/IReservoirRouter.sol";
import { IGenericFactory } from "src/interfaces/IGenericFactory.sol";

contract ReservoirRouter {
    IGenericFactory public factory;

    constructor (address aFactory) {
        factory = IGenericFactory(aFactory);
    }
}
