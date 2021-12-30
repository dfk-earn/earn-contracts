// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDFKQuest.sol";
import "hardhat/console.sol";

contract MockQuest is IDFKQuest {
    function startQuest(
        uint256[] calldata _heroIds,
        address _questAddress,
        uint8 _attempts
    )
        external
        view
        override
    {
        console.log(
            "startQuest: %d heros, %d attempts, %s",
            _heroIds.length,
            _attempts,
            _questAddress
        );
    }

    function cancelQuest(uint256 _heroId) external view override {
        console.log("cancelQuest: heroId %d", _heroId);
    }

    function completeQuest(uint256 _heroId) external view override {
        console.log("completeQuest: heroId %d", _heroId);
    }
}
