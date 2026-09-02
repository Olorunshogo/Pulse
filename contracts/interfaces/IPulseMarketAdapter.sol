// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPulseMarketAdapter {
    enum MarketStatus {
        Listed,
        Trading,
        Locked,
        Resolved,
        Voided
    }

    function status(bytes32 marketId) external view returns (MarketStatus);
    function place(bytes32 marketId, uint8 side, uint256 stake, address owner) external returns (bytes32 orderId);
    function redeemHeld(address holder, bytes32 marketId) external returns (uint256 credited);
}
