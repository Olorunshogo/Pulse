// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Minimal} from "./interfaces/IERC20Minimal.sol";
import {IERC6909Minimal} from "./interfaces/IERC6909Minimal.sol";
import {IPulseMarketAdapter} from "./interfaces/IPulseMarketAdapter.sol";
import {ISomniaBinaryMarket} from "./interfaces/ISomniaBinaryMarket.sol";
import {ISomniaBinaryModule} from "./interfaces/ISomniaBinaryModule.sol";
import {ISomniaBinaryPool} from "./interfaces/ISomniaBinaryPool.sol";

contract SomniaBinaryAdapter is IPulseMarketAdapter {
    uint8 internal constant BUY_YES = 0;
    uint8 internal constant BUY_NO = 2;
    uint8 internal constant ORDER_TYPE_MARKET = 2;
    uint8 internal constant SELF_MATCH_CANCEL_TAKER = 0;
    uint256 internal constant ONE_COLLATERAL = 1e6;

    ISomniaBinaryModule public immutable module;
    IERC20Minimal public immutable collateral;
    IERC6909Minimal public immutable outcomeToken;
    uint256 public immutable maxYesPrice;
    uint256 public immutable maxNoPrice;
    bool public moduleApproved;

    mapping(address holder => mapping(bytes32 marketId => mapping(uint8 outcomeIdx => uint256 amount))) public held;

    struct OrderParams {
        uint8 kind;
        uint8 outcomeIdx;
        uint256 yesPrice;
        uint256 sidePrice;
    }

    event OutcomeRecorded(address indexed holder, bytes32 indexed marketId, uint8 indexed outcomeIdx, uint256 amount);
    event CollateralRefunded(address indexed holder, bytes32 indexed marketId, uint256 amount);

    error InvalidAddress();
    error InvalidSide(uint8 side);
    error InvalidPrice();
    error OperatorApprovalFailed();
    error UnknownMarket(bytes32 marketId);
    error PlaceRejected();
    error TransferFailed();

    constructor(
        address module_,
        address collateral_,
        address outcomeToken_,
        uint256 maxYesPrice_,
        uint256 maxNoPrice_
    ) {
        if (module_ == address(0) || collateral_ == address(0) || outcomeToken_ == address(0)) revert InvalidAddress();
        if (maxYesPrice_ == 0 || maxYesPrice_ > ONE_COLLATERAL || maxNoPrice_ == 0 || maxNoPrice_ > ONE_COLLATERAL) {
            revert InvalidPrice();
        }

        module = ISomniaBinaryModule(module_);
        collateral = IERC20Minimal(collateral_);
        outcomeToken = IERC6909Minimal(outcomeToken_);
        maxYesPrice = maxYesPrice_;
        maxNoPrice = maxNoPrice_;
    }

    function approveModule() external {
        if (moduleApproved) return;

        _setOutcomeOperator(address(outcomeToken), address(module));
        moduleApproved = true;
    }

    function status(bytes32 marketId) external view returns (MarketStatus) {
        ISomniaBinaryModule.MarketRecord memory record = module.markets(marketId);
        if (record.market == address(0)) return MarketStatus.Listed;

        uint8 rawStatus = ISomniaBinaryMarket(record.market).status();
        if (rawStatus == 1) return MarketStatus.Trading;
        if (rawStatus == 2 || rawStatus == 3) return MarketStatus.Locked;
        if (rawStatus == 4) return MarketStatus.Resolved;
        if (rawStatus == 5) return MarketStatus.Voided;
        return MarketStatus.Listed;
    }

    function place(bytes32 marketId, uint8 side, uint256 stake, address holder) external returns (bytes32 orderId) {
        if (holder == address(0)) revert InvalidAddress();

        ISomniaBinaryModule.MarketRecord memory record = module.markets(marketId);
        if (record.pool == address(0)) revert UnknownMarket(marketId);

        OrderParams memory params = _orderParams(side);
        uint256 quantity = (stake * ONE_COLLATERAL) / params.sidePrice;
        if (quantity == 0) revert InvalidPrice();

        uint256 collateralBefore = collateral.balanceOf(address(this));
        if (!collateral.transferFrom(msg.sender, address(this), stake)) revert TransferFailed();
        collateral.approve(record.pool, stake);

        uint256 outcomeId = params.outcomeIdx == 0 ? record.yesId : record.noId;
        uint256 outcomeBefore = outcomeToken.balanceOf(address(this), outcomeId);

        (bool success, uint128 id) = ISomniaBinaryPool(record.pool).placeBinaryOrder(
            params.kind,
            params.yesPrice,
            quantity,
            uint64(record.expiry) * 1_000_000_000,
            ORDER_TYPE_MARKET,
            SELF_MATCH_CANCEL_TAKER,
            address(0),
            0,
            0
        );
        if (!success) revert PlaceRejected();

        _recordFill(holder, marketId, params.outcomeIdx, outcomeToken.balanceOf(address(this), outcomeId) - outcomeBefore);

        _refundCollateral(holder, marketId, collateral.balanceOf(address(this)) - collateralBefore);

        return bytes32(uint256(id));
    }

    function redeemHeld(address holder, bytes32 marketId) external returns (uint256 credited) {
        uint256 beforeBalance = collateral.balanceOf(address(this));
        _redeemOutcome(holder, marketId, 0);
        _redeemOutcome(holder, marketId, 1);
        credited = collateral.balanceOf(address(this)) - beforeBalance;

        if (credited > 0 && !collateral.transfer(holder, credited)) revert TransferFailed();
    }

    function _orderParams(uint8 side) internal view returns (OrderParams memory params) {
        if (side == 0) {
            return OrderParams({kind: BUY_YES, outcomeIdx: 0, yesPrice: maxYesPrice, sidePrice: maxYesPrice});
        }
        if (side == 1) {
            return OrderParams({kind: BUY_NO, outcomeIdx: 1, yesPrice: ONE_COLLATERAL - maxNoPrice, sidePrice: maxNoPrice});
        }
        revert InvalidSide(side);
    }

    function _redeemOutcome(address holder, bytes32 marketId, uint8 outcomeIdx) internal {
        uint256 amount = held[holder][marketId][outcomeIdx];
        if (amount == 0) return;

        if (!moduleApproved) {
            _setOutcomeOperator(address(outcomeToken), address(module));
            moduleApproved = true;
        }

        ISomniaBinaryModule.MarketRecord memory record = module.markets(marketId);
        (bool ok,) = address(module).call(
            abi.encodeCall(
                ISomniaBinaryModule.redeem,
                (record.originOperatorId, record.originVenueId, marketId, outcomeIdx, amount)
            )
        );

        if (ok) {
            held[holder][marketId][outcomeIdx] = 0;
        }
    }

    function _recordFill(address holder, bytes32 marketId, uint8 outcomeIdx, uint256 amount) internal {
        if (amount == 0) return;

        held[holder][marketId][outcomeIdx] += amount;
        emit OutcomeRecorded(holder, marketId, outcomeIdx, amount);
    }

    function _refundCollateral(address holder, bytes32 marketId, uint256 amount) internal {
        if (amount == 0) return;

        if (!collateral.transfer(holder, amount)) revert TransferFailed();
        emit CollateralRefunded(holder, marketId, amount);
    }

    function _setOutcomeOperator(address outcomeToken_, address spender) internal {
        (bool ok, bytes memory data) = outcomeToken_.call(abi.encodeWithSignature("setOperator(address,bool)", spender, true));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert OperatorApprovalFailed();
    }
}
