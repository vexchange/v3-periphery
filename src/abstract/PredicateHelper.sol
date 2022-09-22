pragma solidity 0.8.13;

abstract contract PredicateHelper {
    function checkDeadline(uint256 deadline) external view {
        require(block.timestamp <= deadline, "PH: TX_TOO_OLD");
    }
}
