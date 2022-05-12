// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IAccount.sol";
import "./interfaces/IAccountFactory.sol";

contract DFKEarnBase {
    address public immutable accountFactory;

    constructor(address _accountFacotry) {
        accountFactory = _accountFacotry;
    }

    function withdrawalNativeToken(uint _amount) external {
        address account = getAccount(msg.sender);
        IAccount(account).sendValue(payable(msg.sender), _amount);
    }

    function batchWithdrawalERC20Tokens(
        address[] calldata _erc20Tokens,
        uint[] calldata _amounts
    )
        external
    {
        address account = getAccount(msg.sender);
        for (uint i = 0; i < _erc20Tokens.length; i++) {
            IAccount(account).functionCall(_erc20Tokens[i], abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                _amounts[i]
            ));
        }
    }

    function batchWithdrawalERC721Tokens(
        address _erc721Token,
        uint[] calldata _ids
    )
        external
    {
        address account = getAccount(msg.sender);
        for (uint i = 0; i < _ids.length; i++) {
            IAccount(account).functionCall(_erc721Token, abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                account,
                msg.sender,
                _ids[i]
            ));
        }
    }

    function batchWithdrawalERC1155Tokens(
        address _erc1155Token,
        uint[] calldata _ids,
        uint[] calldata _amounts
    )
        external
    {
        address account = getAccount(msg.sender);
        for (uint i = 0; i < _ids.length; i++) {
            IAccount(account).functionCall(_erc1155Token, abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                account,
                msg.sender,
                _ids[i],
                _amounts[i],
                ""
            ));
        }
    }

    function tryGetAccount(address user) public view returns (address) {
        return IAccountFactory(accountFactory).accounts(user);
    }

    function getAccount(address user) public view returns (address) {
        address account = tryGetAccount(user);
        require(account != address(0), "DFKEarn: no account");
        return account;
    }

    function hasAccount(address user) public view returns (bool) {
        return tryGetAccount(user) != address(0);
    }
}
