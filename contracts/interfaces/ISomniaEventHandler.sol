// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISomniaEventHandler {
    function onEvent(bytes calldata eventData) external;
}
