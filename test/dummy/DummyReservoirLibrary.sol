pragma solidity ^0.8.0;

import { ReservoirLibrary } from "src/libraries/ReservoirLibrary.sol";

contract DummyReservoirLibrary {
    function getSwapFee(address aFactory, address aTokenA, address aTokenB, uint256 aCurveId)
        external
        view
        returns (uint256)
    {
        return ReservoirLibrary.getSwapFee(aFactory, aTokenA, aTokenB, aCurveId);
    }

    function getPrecisionMultiplier(address aToken) external view returns (uint64) {
        return ReservoirLibrary.getPrecisionMultiplier(aToken);
    }
}
