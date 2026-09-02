// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC6909Minimal {
    function balanceOf(address owner, uint256 id) external view returns (uint256);
}
