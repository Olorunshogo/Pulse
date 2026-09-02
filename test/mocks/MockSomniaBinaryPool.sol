// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Minimal} from "../../contracts/interfaces/IERC20Minimal.sol";
import {MockERC6909} from "./MockERC6909.sol";

contract MockSomniaBinaryPool {
    IERC20Minimal public immutable collateral;
    MockERC6909 public immutable outcomeToken;
    uint256 public immutable yesId;
    uint256 public immutable noId;

    uint256 public fillBps = 10_000;
    uint128 public nextOrderId = 1;

    constructor(IERC20Minimal collateral_, MockERC6909 outcomeToken_, uint256 yesId_, uint256 noId_) {
        collateral = collateral_;
        outcomeToken = outcomeToken_;
        yesId = yesId_;
        noId = noId_;
    }

    function setFillBps(uint256 fillBps_) external {
        fillBps = fillBps_;
    }

    function placeBinaryOrder(
        uint8 kind,
        uint256 price,
        uint256 quantity,
        uint64,
        uint8,
        uint8,
        address,
        uint96,
        uint64
    ) external payable returns (bool success, uint128 id) {
        uint8 outcomeIdx = kind == 2 ? 1 : 0;
        uint256 sidePrice = outcomeIdx == 0 ? price : 1e6 - price;
        uint256 cost = (quantity * sidePrice + 1e6 - 1) / 1e6;
        collateral.transferFrom(msg.sender, address(this), cost);

        uint256 filled = (quantity * fillBps) / 10_000;
        if (filled > 0) {
            outcomeToken.mint(msg.sender, outcomeIdx == 0 ? yesId : noId, filled);
        }

        uint256 used = (filled * sidePrice + 1e6 - 1) / 1e6;
        if (cost > used) {
            collateral.transfer(msg.sender, cost - used);
        }

        success = true;
        id = nextOrderId++;
    }
}

