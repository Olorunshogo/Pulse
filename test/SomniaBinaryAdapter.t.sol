// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SomniaBinaryAdapter} from "../contracts/SomniaBinaryAdapter.sol";
import {IERC20Minimal} from "../contracts/interfaces/IERC20Minimal.sol";
import {IPulseMarketAdapter} from "../contracts/interfaces/IPulseMarketAdapter.sol";
import {ISomniaBinaryModule} from "../contracts/interfaces/ISomniaBinaryModule.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC6909} from "./mocks/MockERC6909.sol";
import {MockSomniaBinaryMarket} from "./mocks/MockSomniaBinaryMarket.sol";
import {MockSomniaBinaryModule} from "./mocks/MockSomniaBinaryModule.sol";
import {MockSomniaBinaryPool} from "./mocks/MockSomniaBinaryPool.sol";

contract SomniaBinaryAdapterTest is Test {
    address internal session = address(0x515510);
    bytes32 internal marketId = keccak256("ETH-15m-1");
    uint256 internal yesId = 100;
    uint256 internal noId = 101;

    MockERC20 internal collateral;
    MockERC6909 internal outcomeToken;
    MockSomniaBinaryMarket internal market;
    MockSomniaBinaryModule internal module;
    MockSomniaBinaryPool internal pool;
    SomniaBinaryAdapter internal adapter;

    function setUp() public {
        collateral = new MockERC20();
        outcomeToken = new MockERC6909();
        market = new MockSomniaBinaryMarket();
        module = new MockSomniaBinaryModule(IERC20Minimal(address(collateral)), outcomeToken);
        pool = new MockSomniaBinaryPool(IERC20Minimal(address(collateral)), outcomeToken, yesId, noId);
        adapter = new SomniaBinaryAdapter(address(module), address(collateral), address(outcomeToken), 990_000, 990_000);

        module.setMarket(marketId, _record());

        collateral.mint(session, 100e6);
        vm.prank(session);
        collateral.approve(address(adapter), 100e6);
    }

    function testStatusMapsSomniaStates() public {
        assertFalse(adapter.moduleApproved());

        assertEq(uint8(adapter.status(marketId)), uint8(IPulseMarketAdapter.MarketStatus.Trading));

        market.setStatus(3);
        assertEq(uint8(adapter.status(marketId)), uint8(IPulseMarketAdapter.MarketStatus.Locked));

        market.setStatus(4);
        assertEq(uint8(adapter.status(marketId)), uint8(IPulseMarketAdapter.MarketStatus.Resolved));

        market.setStatus(5);
        assertEq(uint8(adapter.status(marketId)), uint8(IPulseMarketAdapter.MarketStatus.Voided));
    }

    function testPlaceRecordsFilledOutcomeForHolder() public {
        vm.prank(session);
        bytes32 orderId = adapter.place(marketId, 0, 990_000, session);

        assertEq(uint256(orderId), 1);
        assertEq(adapter.held(session, marketId, 0), 1e6);
        assertEq(outcomeToken.balanceOf(address(adapter), yesId), 1e6);
        assertEq(collateral.balanceOf(session), 99_010_000);
    }

    function testPlaceRefundsUnfilledCollateral() public {
        pool.setFillBps(5_000);

        vm.prank(session);
        adapter.place(marketId, 0, 990_000, session);

        assertEq(adapter.held(session, marketId, 0), 500_000);
        assertEq(collateral.balanceOf(session), 99_505_000);
    }

    function testRedeemBurnsOnlyTrackedHolderAmount() public {
        vm.prank(session);
        adapter.place(marketId, 0, 990_000, session);

        collateral.mint(address(module), 2e6);
        adapter.redeemHeld(session, marketId);

        assertTrue(adapter.moduleApproved());
        assertEq(adapter.held(session, marketId, 0), 0);
        assertEq(outcomeToken.balanceOf(address(adapter), yesId), 0);
        assertEq(collateral.balanceOf(session), 100_010_000);
    }

    function testRedeemLeavesFailedOutcomeTracked() public {
        vm.prank(session);
        adapter.place(marketId, 0, 990_000, session);

        collateral.mint(address(module), 2e6);
        module.setFailRedeem(marketId, 0, true);
        adapter.redeemHeld(session, marketId);

        assertEq(adapter.held(session, marketId, 0), 1e6);
        assertEq(outcomeToken.balanceOf(address(adapter), yesId), 1e6);
        assertEq(collateral.balanceOf(session), 99_010_000);
    }

    function _record() internal view returns (ISomniaBinaryModule.MarketRecord memory record) {
        record.collateral = address(collateral);
        record.originOperatorId = 7;
        record.originVenueId = bytes32("pulse");
        record.market = address(market);
        record.pool = address(pool);
        record.yesId = yesId;
        record.noId = noId;
        record.expiry = uint64(block.timestamp + 15 minutes);
    }
}
