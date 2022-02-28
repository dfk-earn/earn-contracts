// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DFKEarnBase.sol";

contract DFKEarnQuest is DFKEarnBase {
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

    address public immutable DFKQuest;
    IERC20 public immutable JEWEL;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private operators;

    mapping(address => bool) public supportedQuest;
    uint private feePerHero = 0.12 ether;

    uint256 public extraFeeThreshold = 0.25e18;  // 0.25 jewel
    uint256 public extraFeeRate = 250; // in bps

    event QuestFeeChanged(uint256 newValue, uint256 oldValue);
    event QuestTypeAdded(address quest);

    constructor(
        address _accountFactory,
        address _DFKQuest,
        address _JEWEL
    )
        DFKEarnBase(_accountFactory)
    {
        DFKQuest = _DFKQuest;
        JEWEL = IERC20(_JEWEL);
    }

    modifier onlyOperator() {
        require(operators.contains(msg.sender), "DFKEarn: not operator");
        _;
    }

    function startQuest(
        address _account,
        uint256[] calldata _heroIds,
        address _quest,
        uint8 _attempts
    ) 
        external
        onlyOperator
    {
        uint256 fee = _heroIds.length * feePerHero;
        require(_account.balance >= fee, "DFKEarn: insufficent balance");
        require(supportedQuest[_quest], "DFKEarn: unsupported quest");
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "startQuest(uint256[],address,uint8)",
            _heroIds,
            _quest,
            _attempts
        ));
        IAccount(_account).sendValue(payable(admin), fee);
    }

    function startQuestWithData(
        address _account,
        uint256[] calldata _heroIds,
        address _quest,
        uint8 _attempts,
        QuestData calldata _questData
    )
        external
        onlyOperator
    {
        uint256 fee = _heroIds.length * feePerHero;
        require(_account.balance >= fee, "DFKEarn: insufficent balance");
        require(supportedQuest[_quest], "DFKEarn: unsupported quest");
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "startQuestWithData(uint256[],address,uint8,(uint256,uint256,uint256,uint256,int256,int256,string,string,address,address,address,address))",
            _heroIds,
            _quest,
            _attempts,
            _questData
        ));
        IAccount(_account).sendValue(payable(admin), fee);
    }

    function cancelQuest(address _account, uint256 _heroId) external onlyOperator {
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "cancelQuest(uint256)",
            _heroId
        ));
    }

    function completeQuest(address _account, uint256 _heroId) external onlyOperator {
        uint256 balanceBefore = JEWEL.balanceOf(_account);
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "completeQuest(uint256)",
            _heroId
        ));
        uint256 balanceAfter = JEWEL.balanceOf(_account);
        uint256 profit = balanceAfter - balanceBefore;
        if (profit >= extraFeeThreshold) {
            uint256 extraFee = profit * extraFeeRate / 10_000;
            IAccount(_account).functionCall(address(JEWEL), abi.encodeWithSignature(
                "transfer(address,uint256)",
                admin,
                extraFee
            ));
        }
    }

    function addQuestType(address _quest) external onlyAdmin {
        if (!supportedQuest[_quest]) {
            supportedQuest[_quest] = true;
            emit QuestTypeAdded(_quest);
        }
    }

    function setFeePerHero(uint256 _feePerHero) external onlyAdmin {
        uint256 oldValue = feePerHero;
        feePerHero = _feePerHero;
        emit QuestFeeChanged(feePerHero, oldValue);
    }

    function setExtraFeeThreshold(uint256 _extraFeeThreshold) external onlyAdmin {
        extraFeeThreshold = _extraFeeThreshold;
    }

    function setExtraFeeRate(uint256 _extraFeeRate) external onlyAdmin {
        extraFeeRate = _extraFeeRate;
    }

    function addOperator(address _operator) external onlyAdmin {
        operators.add(_operator);
    }

    function removeOperator(address _operator) external onlyAdmin {
        operators.remove(_operator);
    }

    function getOperators() public view returns (address[] memory) {
        uint length = operators.length();
        address[] memory result = new address[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = operators.at(i);
        }
        return result;
    }
}
