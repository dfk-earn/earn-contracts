// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

enum ItemType { ERC20, ERC721, ERC1155 }
struct Item {
    ItemType itemType;
    address addr;
    uint[] amounts;
    uint[] ids;
}

contract Market is Ownable, Pausable, ERC721Holder, ERC1155Holder {
    using SafeERC20 for IERC20;

    IERC20 public immutable money;

    uint public commission; // in bps

    event CommissionChanged(uint newCommission, uint oldCommission);

    constructor(address _money, uint _commission) {
        money = IERC20(_money);
        commission = _commission;
    }

    function setComission(uint _commission) external onlyOwner {
        uint oldCommission = commission;
        commission = _commission;
        emit CommissionChanged(commission, oldCommission);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function transferItem(address _from, address _to, Item memory _item) internal {
        if (_item.itemType == ItemType.ERC721) {
            require(_item.ids.length > 0, "Market: zero ids.length");
            for (uint i = 0; i < _item.ids.length; i++) {
                IERC721(_item.addr).safeTransferFrom(_from, _to, _item.ids[i]);
            }
        } else if (_item.itemType == ItemType.ERC1155) {
            require(_item.ids.length > 0, "Market: zero ids.length");
            require(
                _item.ids.length == _item.amounts.length,
                "Market: ids.length and amounts.length are not equal"
            );
            for (uint i = 0; i < _item.ids.length; i++) {
                require(_item.amounts[i] > 0, "Market: zero amount");
                IERC1155(_item.addr).safeTransferFrom(_from, _to, _item.ids[i], _item.amounts[i], "");
            }
        } else if (_item.itemType == ItemType.ERC20) {
            require(_item.amounts.length > 0, "Market: zero amounts.length");
            require(_item.amounts[0] > 0, "Market: zero amount");
            safeTransferERC20(_item.addr, _from, _to, _item.amounts[0]);
        } else {
            revert("Market: unsupported itemType");
        }
    }

    function transferMoney(address _from, address _to, uint _amount) internal {
        safeTransferERC20(address(money), _from, _to, _amount);
    }

    function safeTransferERC20(
        address _token,
        address _from,
        address _to,
        uint _amount
    )
        private
    {
        if (_from == address(this)) {
            IERC20(_token).safeTransfer(_to, _amount);
        } else {
            IERC20(_token).safeTransferFrom(_from, _to, _amount);
        }
    }
}
