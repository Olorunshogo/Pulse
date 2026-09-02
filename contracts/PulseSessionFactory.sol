// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PulseSession} from "./PulseSession.sol";

contract PulseSessionFactory {
    address public immutable implementation;
    address public immutable collateral;
    address public immutable marketAdapter;

    mapping(address owner => address session) public sessionOf;

    event SessionCreated(address indexed owner, address indexed session);

    error InvalidAddress();
    error SessionAlreadyExists(address owner);
    error CloneFailed();

    constructor(address collateral_, address marketAdapter_) {
        if (collateral_ == address(0) || marketAdapter_ == address(0)) revert InvalidAddress();

        implementation = address(new PulseSession());
        collateral = collateral_;
        marketAdapter = marketAdapter_;
    }

    function createSession(
        PulseSession.Policy calldata policy,
        bytes32[] calldata allowedMarketIds
    ) external returns (address session) {
        if (sessionOf[msg.sender] != address(0)) revert SessionAlreadyExists(msg.sender);

        session = _clone(implementation);
        PulseSession(session).initialize(msg.sender, collateral, marketAdapter, policy, allowedMarketIds);
        sessionOf[msg.sender] = session;

        emit SessionCreated(msg.sender, session);
    }

    function _clone(address target) internal returns (address clone) {
        bytes20 targetBytes = bytes20(target);

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), targetBytes)
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            clone := create(0, ptr, 0x37)
        }

        if (clone == address(0)) revert CloneFailed();
    }
}
