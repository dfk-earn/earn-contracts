// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDFKBank {
    function enter(uint256 _amount) external;
    function leave(uint256 _share) external;
}