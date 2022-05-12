// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDFKQuest {
    function startQuest(uint256[] calldata _heroIds, address _quest, uint8 _attempts, uint8 _level) external;    
    function cancelQuest(uint256 _heroId) external;
    function completeQuest(uint256 _heroId) external;
}