// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccount {
    event Received(address indexed sender, uint value);
    event WhitelistAdded(address indexed _address);
    event WhitelistRemoved(address indexed _address);

    function factory() external view returns (address);
    function owner() external view returns (address);
    function sendValue(address payable _recipient, uint256 _amount) external payable;
    function functionCall(address _target, bytes memory _data) external payable returns (bytes memory result);
    function functionCallWithValue(address _target, bytes memory _data, uint _value) external payable returns (bytes memory result);
    function isWhitelisted(address _address) external view returns(bool);
    function getWhitelist() external view returns (address[] memory);
    function updateWhitelist(address[] memory _toAdd, address[] memory _toRemove) external;
    function addToWhitelist(address[] memory _toAdd) external;
    function removeFromWhitelist(address[] memory _toRemove) external;
}
