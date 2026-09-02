// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockERC6909 {
    mapping(address owner => mapping(uint256 id => uint256 balance)) public balanceOf;
    mapping(address owner => mapping(address operator => bool approved)) public isOperator;

    function mint(address to, uint256 id, uint256 amount) external {
        balanceOf[to][id] += amount;
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(balanceOf[from][id] >= amount, "BALANCE");
        balanceOf[from][id] -= amount;
    }

    function setOperator(address spender, bool approved) external {
        isOperator[msg.sender][spender] = approved;
    }
}
