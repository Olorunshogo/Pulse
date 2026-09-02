// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Minimal} from "../../contracts/interfaces/IERC20Minimal.sol";
import {ISomniaBinaryModule} from "../../contracts/interfaces/ISomniaBinaryModule.sol";
import {MockERC6909} from "./MockERC6909.sol";

contract MockSomniaBinaryModule is ISomniaBinaryModule {
    IERC20Minimal public immutable collateral;
    MockERC6909 public immutable outcomeToken;

    mapping(bytes32 marketId => MarketRecord record) internal records;
    mapping(bytes32 marketId => mapping(uint8 outcomeIdx => bool failing)) public failRedeem;

    constructor(IERC20Minimal collateral_, MockERC6909 outcomeToken_) {
        collateral = collateral_;
        outcomeToken = outcomeToken_;
    }

    function setMarket(bytes32 marketId, MarketRecord calldata record) external {
        records[marketId] = record;
    }

    function setFailRedeem(bytes32 marketId, uint8 outcomeIdx, bool failing) external {
        failRedeem[marketId][outcomeIdx] = failing;
    }

    function markets(bytes32 marketId) external view returns (MarketRecord memory record) {
        return records[marketId];
    }

    function redeem(
        uint32,
        bytes32,
        bytes32 marketId,
        uint8 outcomeIdx,
        uint256 amount
    ) external {
        require(!failRedeem[marketId][outcomeIdx], "REDEEM_FAILED");

        MarketRecord memory record = records[marketId];
        uint256 outcomeId = outcomeIdx == 0 ? record.yesId : record.noId;
        outcomeToken.burn(msg.sender, outcomeId, amount);
        collateral.transfer(msg.sender, amount);
    }
}

