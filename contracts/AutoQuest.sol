// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DFKEarnBase.sol";

contract AutoQuest is Ownable, DFKEarnBase {
    address public constant DFKQuest = 0xAa9a289ce0565E4D6548e63a441e7C084E6B52F6;
    address public constant DFKJewelToken = 0x72Cb10C6bfA5624dD07Ef608027E366bd690048F;
    address public constant DFKGoldToken = 0x3a4EDcf3312f44EF027acfd8c21382a5259936e7;
    address public constant DFKVender = 0xe53BF78F8b99B6d356F93F41aFB9951168cca2c6;
    address public constant DFKAlchemist = 0x38e76972BD173901B5E5E43BA5cB464293B80C31;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private operators;

    uint public questFee;
    uint public jewelFeeRate;
    uint public jewelFeeThreshold;
    uint public goldFeeRate;
    uint public goldFeeThreshold;
    uint public sellItemFeeRate;
    uint public sellItemFeeThreshold;

    constructor(address _accountFactory) DFKEarnBase(_accountFactory) {
        questFee = 0.12 ether;
        jewelFeeRate = 250;                 // in bps
        jewelFeeThreshold = 0.25e18;        // 0.25 jewel
        goldFeeRate = 250;                  // in bps
        goldFeeThreshold = 200e3;           // 200 gold
        sellItemFeeRate = 250;              // in bps
        sellItemFeeThreshold = 200e3;       // 200 gold
    }

    modifier onlyOperator() {
        require(operators.contains(msg.sender), "DFKEarn: not operator");
        _;
    }

    function startQuest(
        address _account,
        uint256[] calldata _heroIds,
        address _quest,
        uint8 _attempts,
        uint8 _level
    ) 
        external
        onlyOperator
    {
        chargeQuestFee(_account, _heroIds.length);
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "startQuest(uint256[],address,uint8,uint8)",
            _heroIds,
            _quest,
            _attempts,
            _level
        ));
    }

    function cancelQuest(address _account, uint256 _heroId) external onlyOperator {
        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "cancelQuest(uint256)",
            _heroId
        ));
    }

    function completeQuest(address _account, uint256 _heroId) external onlyOperator {
        uint oldGoldBalance = IERC20(DFKGoldToken).balanceOf(_account);
        uint oldJewelBalance = IERC20(DFKJewelToken).balanceOf(_account);

        IAccount(_account).functionCall(DFKQuest, abi.encodeWithSignature(
            "completeQuest(uint256)",
            _heroId
        ));

        chargeGoldEarnings(_account, oldGoldBalance);
        chargeJewelEarnings(_account, oldJewelBalance);
    }

    function craftPotion(address _account, address _item, uint256 _heroId) external onlyOperator {
        IAccount(_account).functionCall(DFKAlchemist, abi.encodeWithSignature(
            "consumeItem(address,uint256)",
            _item,
            _heroId
        ));
    }

    function sellToVender(address[] calldata _items, uint[] calldata _amounts) external {
        address account = getAccount(msg.sender);
        uint256 oldGoldBalance = IERC20(DFKGoldToken).balanceOf(account);
        for (uint i = 0; i < _items.length; i++) {
            uint balance = IERC20(_items[i]).balanceOf(account);
            require(_amounts[i] <= balance, "DFKEarn: insufficient balance");
            IAccount(account).functionCall(_items[i], abi.encodeWithSignature(
                "approve(address,uint256)",
                DFKVender,
                _amounts[i]
            ));
            IAccount(account).functionCall(DFKVender, abi.encodeWithSelector(
                bytes4(0x096c5e1a),
                _items[i],
                _amounts[i]
            ));
        }
        chargeGoldEarnings(account, oldGoldBalance);
    }

    function chargeQuestFee(
        address _account,
        uint _heroCount
    )
        private
    {
        uint256 totalQuestFee = _heroCount * questFee;
        require(_account.balance >= totalQuestFee, "AutoQuest: insufficent balance");
        IAccount(_account).sendValue(payable(owner()), totalQuestFee);
    }

    function chargeGoldEarnings(address _account, uint _oldBalance) private {
        uint earnings = IERC20(DFKGoldToken).balanceOf(_account) - _oldBalance;
        if (earnings >= goldFeeThreshold) {
            uint fee = earnings * goldFeeRate / 10000;
            IAccount(_account).functionCall(DFKGoldToken, abi.encodeWithSignature(
                "transfer(address,uint256)",
                owner(),
                fee
            ));
        }
    }

    function chargeJewelEarnings(address _account, uint _oldBalance) private {
        uint earnings = IERC20(DFKJewelToken).balanceOf(_account) - _oldBalance;
        if (earnings >= jewelFeeThreshold) {
            uint fee = earnings * jewelFeeRate / 10000;
            IAccount(_account).functionCall(DFKJewelToken, abi.encodeWithSignature(
                "transfer(address,uint256)",
                owner(),
                fee
            ));
        }
    }

    function setQuestFee(uint256 _questFee) external onlyOwner {
        questFee = _questFee;
    }

    function setJewelFeeRate(uint256 _jewelFeeRate) external onlyOwner {
        jewelFeeRate = _jewelFeeRate;
    }

    function setJewelFeeThreshold(uint256 _jewelFeeThreshold) external onlyOwner {
        jewelFeeThreshold = _jewelFeeThreshold;
    }

    function setGoldFeeRate(uint256 _goldFeeRate) external onlyOwner {
        goldFeeRate = _goldFeeRate;
    }

    function setGoldFeeThreshold(uint256 _goldFeeThreshold) external onlyOwner {
        goldFeeThreshold = _goldFeeThreshold;
    }

    function setSellItemFeeRate(uint256 _sellItemFeeRate) external onlyOwner {
        sellItemFeeRate = _sellItemFeeRate;
    }

    function setSellItemFeeThreshold(uint256 _sellItemFeeThreshold) external onlyOwner {
        sellItemFeeThreshold = _sellItemFeeThreshold;
    }

    function updateOperator(address _operator, bool _add) external onlyOwner {
        if (_add) {
            operators.add(_operator);
        } else {
            operators.remove(_operator);
        }
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
