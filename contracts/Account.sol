// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IAccount.sol";

contract Account is IAccount, ERC721Holder, ERC1155Holder {
    address public override factory;
    address public override owner;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private whitelist;

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _owner, address[] calldata _whitelist) external payable {
        require(msg.sender == factory, "Account: no permission");
        owner = _owner;
        _updateWhitelist(_whitelist, new address[](0));
        if (address(this).balance > 0) {
            emit Received(address(0), address(this).balance);
        }
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function sendValue(
        address payable _recipient,
        uint256 _amount
    )
        external
        payable
        override
        onlyWhitelisted
    {
        Address.sendValue(_recipient, _amount);
    }

    function functionCall(
        address _target,
        bytes memory _data
    )
        external
        payable
        override
        onlyWhitelisted
        returns (bytes memory)
    {
        return Address.functionCall(_target, _data);
    }

    function functionCallWithValue(
        address _target,
        bytes memory _data,
        uint _value
    )
        external
        payable
        override
        onlyWhitelisted
        returns (bytes memory)
    {
        return Address.functionCallWithValue(_target, _data, _value);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Account: not owner");
        _;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted(msg.sender), "Account: not whitelisted");
        _;
    }

    function isWhitelisted(address _address) public view override returns(bool) {
        return _address == owner || whitelist.contains(_address);
    }

    function getWhitelist() public view override returns (address[] memory) {
        uint length = whitelist.length();
        address[] memory result = new address[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = whitelist.at(i);
        }
        return result;
    }

    function updateWhitelist(
        address[] memory _toAdd,
        address[] memory _toRemove
    )
        public
        override
        onlyOwner
    {
        _updateWhitelist(_toAdd, _toRemove);
    }

    function addToWhitelist(address[] memory _toAdd) public override onlyOwner {
        _updateWhitelist(_toAdd, new address[](0));
    }

    function removeFromWhitelist(address[] memory _toRemove) public override onlyOwner {
        _updateWhitelist(new address[](0), _toRemove);
    }

    function _updateWhitelist(
        address[] memory _toAdd,
        address[] memory _toRemove
    )
        internal
    {
        for (uint i = 0; i < _toAdd.length; i++) {
            whitelist.add(_toAdd[i]);
            emit WhitelistAdded(_toAdd[i]);
        }

        for (uint i = 0; i < _toRemove.length; i++) {
            whitelist.remove(_toRemove[i]);
            emit WhitelistRemoved(_toRemove[i]);
        }
    }
}
