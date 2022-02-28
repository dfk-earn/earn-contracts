// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MockQuest {
    struct QuestData {
        uint256 uint1;
        uint256 uint2;
        uint256 uint3;
        uint256 uint4;
        int256 int1;
        int256 int2;
        string string1;
        string string2;
        address address1;
        address address2;
        address address3;
        address address4;
    }

    function startQuest(
        uint256[] calldata _heroIds,
        address _questAddress,
        uint8 _attempts
    )
        external
        view
    {
        console.log(
            "startQuest: %d heros, %d attempts, %s",
            _heroIds.length,
            _attempts,
            _questAddress
        );
    }

    function startQuestWithData(
        uint256[] calldata _heroIds,
        address _questAddress,
        uint8 _attempts,
        QuestData calldata _questData
    )
        external
        view
    {
        console.log(
            "startQuestWithData: %d heros, %d attempts, %s, %d",
            _heroIds.length,
            _attempts,
            _questAddress
        );
        console.log("QuestData: string1=%s", _questData.string1);
    }

    function cancelQuest(uint256 _heroId) external view {
        console.log("cancelQuest: heroId %d", _heroId);
    }

    function completeQuest(uint256 _heroId) external view {
        console.log("completeQuest: heroId %d", _heroId);
    }
}
