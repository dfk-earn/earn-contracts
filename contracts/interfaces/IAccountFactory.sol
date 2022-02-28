// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccountFactory {
    event AccountCreated(
        address indexed creator,
        address indexed account,
        uint index
    );

    function accounts(address creator) external view returns (address account);
    function creators(uint256 index) external view returns (address creator);
    function total() external view returns (uint256);
    function createAccount() external payable returns (address account);
    function createAccountWithWhitelist(address[] memory whitelist) external payable returns (address account);
    function hasAccount(address creator) external view returns (bool);
}