// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockSomniaBinaryMarket {
    uint8 public status = 1;

    function setStatus(uint8 status_) external {
        status = status_;
    }
}

