// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "../interfaces/IDFKQuest.sol";

contract MockQuest {
    function startQuest(
        uint256[] calldata _heroIds,
        address /* _questAddress */,
        uint8 _attempts,
        uint8 /* _level */
    )
        external
        view
    {
        console.log(
            "startQuest: %d heros, %d attempts",
            _heroIds.length,
            _attempts
        );
    }

    function cancelQuest(uint256 _heroId) external view {
        console.log("cancelQuest: heroId %d", _heroId);
    }

    function completeQuest(uint256 _heroId) external view {
        console.log("completeQuest: heroId %d", _heroId);
    }
}
