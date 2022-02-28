// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IAccountFactory.sol";
import "./Account.sol";

contract AccountFactory is IAccountFactory {
    // creator address to account address
    mapping(address => address) public override accounts;
    address[] public override creators;

    function createAccountWithWhitelist(
        address[] memory whitelist
    )
        public
        payable
        override
        returns (address account)
    {
        address creator = msg.sender;
        require(accounts[creator] == address(0), "AccountFactory: account exists");
        bytes memory bytecode = type(Account).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(this), creator));
        assembly {
            account := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        Account(payable(account)).initialize{value: msg.value}(creator, whitelist);
        accounts[creator] = account;
        creators.push(creator);
        emit AccountCreated(creator, account, creators.length - 1);
    }

    function createAccount() public payable override returns (address account) {
        return createAccountWithWhitelist(new address[](0));
    }

    function hasAccount(address creator) public view override returns (bool) {
        return accounts[creator] != address(0);
    }

    function total() public view override returns (uint256) {
        return creators.length;
    }
}
