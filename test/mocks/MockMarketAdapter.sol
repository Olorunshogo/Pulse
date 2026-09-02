// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Minimal} from "../../contracts/interfaces/IERC20Minimal.sol";
import {IPulseMarketAdapter} from "../../contracts/interfaces/IPulseMarketAdapter.sol";

contract MockMarketAdapter is IPulseMarketAdapter {
    IERC20Minimal public immutable collateral;

    mapping(bytes32 marketId => MarketStatus status_) public statuses;
    mapping(bytes32 marketId => uint256 payout) public payouts;
    mapping(bytes32 marketId => bool failing) public failRedeem;

    constructor(IERC20Minimal collateral_) {
        collateral = collateral_;
    }

    function setStatus(bytes32 marketId, MarketStatus status_) external {
        statuses[marketId] = status_;
    }

    function setPayout(bytes32 marketId, uint256 payout) external {
        payouts[marketId] = payout;
    }

    function setFailRedeem(bytes32 marketId, bool failing) external {
        failRedeem[marketId] = failing;
    }

    function status(bytes32 marketId) external view returns (MarketStatus) {
        return statuses[marketId];
    }

    function place(bytes32 marketId, uint8, uint256 stake, address) external returns (bytes32 orderId) {
        collateral.transferFrom(msg.sender, address(this), stake);
        orderId = keccak256(abi.encode(marketId, msg.sender, stake, block.number));
    }

    function redeemHeld(address holder, bytes32 marketId) external returns (uint256 credited) {
        if (failRedeem[marketId]) revert("REDEEM_FAILED");

        credited = payouts[marketId];
        if (credited > 0) {
            collateral.transfer(holder, credited);
            payouts[marketId] = 0;
        }
    }
}
