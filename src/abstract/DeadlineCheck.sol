pragma solidity 0.8.17;

abstract contract DeadlineCheck {
    function checkDeadline(uint256 deadline) external view {
        require(block.timestamp <= deadline, "DC: TX_TOO_OLD");
    }
}
