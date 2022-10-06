pragma solidity 0.8.13;

abstract contract PredicateHelper {
    function checkDeadline(uint256 aDeadline) external view {
        require(block.timestamp <= aDeadline, "PH: TX_TOO_OLD");
    }
}
