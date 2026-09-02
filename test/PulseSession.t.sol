// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PulseSession} from "../contracts/PulseSession.sol";
import {PulseSessionFactory} from "../contracts/PulseSessionFactory.sol";
import {IERC20Minimal} from "../contracts/interfaces/IERC20Minimal.sol";
import {IPulseMarketAdapter} from "../contracts/interfaces/IPulseMarketAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockMarketAdapter} from "./mocks/MockMarketAdapter.sol";

contract PulseSessionTest is Test {
    address internal owner = address(0xA11CE);
    bytes32 internal marketOne = keccak256("ETH-15m-1");
    bytes32 internal marketTwo = keccak256("ETH-15m-2");

    MockERC20 internal collateral;
    MockMarketAdapter internal adapter;
    PulseSessionFactory internal factory;
    PulseSession internal session;

    function setUp() public {
        collateral = new MockERC20();
        adapter = new MockMarketAdapter(IERC20Minimal(address(collateral)));
        factory = new PulseSessionFactory(address(collateral), address(adapter));

        bytes32[] memory allowed = new bytes32[](2);
        allowed[0] = marketOne;
        allowed[1] = marketTwo;

        PulseSession.Policy memory policy = PulseSession.Policy({
            maxStakePerWindow: 25e6,
            maxWindows: 2,
            expiry: uint64(block.timestamp + 2 hours),
            rule: PulseSession.Rule.Hold
        });

        vm.prank(owner);
        address sessionAddress = factory.createSession(policy, allowed);
        session = PulseSession(sessionAddress);

        collateral.mint(owner, 200e6);
        vm.prank(owner);
        collateral.approve(address(session), 200e6);
    }

    function testDepositAndWithdrawWhileArmed() public {
        vm.prank(owner);
        session.deposit(100e6);

        vm.prank(owner);
        session.withdraw(40e6);

        assertTrue(session.armed());
        assertEq(collateral.balanceOf(owner), 140e6);
        assertEq(collateral.balanceOf(address(session)), 60e6);
    }

    function testPlaceEnforcesPolicy() public {
        vm.prank(owner);
        session.deposit(100e6);

        adapter.setStatus(marketOne, IPulseMarketAdapter.MarketStatus.Trading);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PulseSession.StakeTooHigh.selector, 26e6, 25e6));
        session.place(marketOne, 0, 26e6);

        vm.prank(owner);
        session.place(marketOne, 0, 25e6);

        assertEq(session.windowsUsed(), 1);
        assertEq(collateral.balanceOf(address(adapter)), 25e6);
    }

    function testPlaceRejectsUnallowedMarket() public {
        bytes32 unknownMarket = keccak256("BTC-15m-unknown");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PulseSession.MarketNotAllowed.selector, unknownMarket));
        session.place(unknownMarket, 0, 10e6);
    }

    function testPlaceRejectsNonTradingMarket() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PulseSession.MarketNotTrading.selector, marketOne));
        session.place(marketOne, 0, 10e6);
    }

    function testWindowLimitIsEnforced() public {
        vm.prank(owner);
        session.deposit(100e6);

        adapter.setStatus(marketOne, IPulseMarketAdapter.MarketStatus.Trading);
        adapter.setStatus(marketTwo, IPulseMarketAdapter.MarketStatus.Trading);

        vm.startPrank(owner);
        session.place(marketOne, 0, 10e6);
        session.place(marketTwo, 0, 10e6);
        vm.expectRevert(PulseSession.WindowLimitReached.selector);
        session.place(marketOne, 0, 10e6);
        vm.stopPrank();
    }

    function testOnlyOwnerCanMoveFunds() public {
        vm.prank(owner);
        session.deposit(100e6);

        vm.prank(address(0xB0B));
        vm.expectRevert(PulseSession.NotOwner.selector);
        session.withdraw(1);
    }

    function testOnEventOnlyAcceptsReactivityPrecompile() public {
        vm.expectRevert(PulseSession.OnlyReactivityPrecompile.selector);
        session.onEvent("");
    }

    function testOnEventIsolatesFailedRedeems() public {
        vm.prank(owner);
        session.deposit(100e6);

        adapter.setStatus(marketOne, IPulseMarketAdapter.MarketStatus.Trading);
        adapter.setStatus(marketTwo, IPulseMarketAdapter.MarketStatus.Trading);

        vm.startPrank(owner);
        session.place(marketOne, 0, 10e6);
        session.place(marketTwo, 0, 10e6);
        vm.stopPrank();

        collateral.mint(address(adapter), 50e6);
        adapter.setPayout(marketOne, 30e6);
        adapter.setPayout(marketTwo, 20e6);
        adapter.setFailRedeem(marketTwo, true);

        vm.prank(session.SOMNIA_REACTIVITY_PRECOMPILE());
        session.onEvent("");

        assertEq(collateral.balanceOf(address(session)), 110e6);
        assertEq(adapter.payouts(marketOne), 0);
        assertEq(adapter.payouts(marketTwo), 20e6);
    }
}
