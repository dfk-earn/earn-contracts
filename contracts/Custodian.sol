// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./Account.sol";

contract Custodian {
    address public immutable DFKQuest;
    address public immutable DFKVender;
    address public immutable DFKGold;

    address public admin;
    address public pendingAdmin;
    address public operator;

    uint256 public fee = 0.1 ether;
    
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    EnumerableMap.UintToAddressMap private playerToAccount;

    mapping(address => bool) public questTypes;

    event AccountCreated(address indexed player, address indexed account, uint playerIndex);

    constructor(address _DFKQuest, address _DFKVender, address _DFKGold) {
        admin = msg.sender;
        operator = msg.sender;
        DFKQuest = _DFKQuest;
        DFKVender = _DFKVender;
        DFKGold = _DFKGold;
    }

    function createAccount() external returns (address account) {
        address player = msg.sender;
        require(!hasAccount(player), 'Custodian: account exists');
        bytes memory bytecode = type(Account).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(this), player));
        assembly {
            account := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        Account(payable(account)).initialize(player);
        playerToAccount.set(uint(uint160(player)), account);
        emit AccountCreated(player, account, playerToAccount.length());
    }

    function playersCount() public view returns (uint256) {
        return playerToAccount.length();
    }

    function getPlayer(uint256 index) public view returns (address) {
        (uint player, ) = playerToAccount.at(index);
        return address(uint160(player));
    }

    function hasAccount(address player) public view returns (bool) {
        return playerToAccount.contains(uint(uint160(player)));
    }

    function getAccount(address player) public view returns (address) {
        return playerToAccount.get(uint(uint160(player)));
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Custodian: admin required");
        _;
    }

    function addQuestType(address _questType) public onlyAdmin {
        questTypes[_questType] = true;
    }

    function setOperator(address _operator) external onlyAdmin {
        operator = _operator;
    }

    function setPendingAdmin(address newPendingAdmin) external onlyAdmin {
        pendingAdmin = newPendingAdmin;
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Custodian: no permission");
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }
}
