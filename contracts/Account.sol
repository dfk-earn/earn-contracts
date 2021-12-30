// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./Custodian.sol";
import "./interfaces/IDFKQuest.sol";

contract Account is ERC721Holder {
    Custodian public custodian;
    address public player;

    constructor() {
        custodian = Custodian(msg.sender);
    }

    function initialize(address _player) external {
        require(msg.sender == address(custodian), "Account: no permission");
        player = _player;
    }

    receive() external payable {}

    modifier onlyPlayer() {
        require(msg.sender == player, "Account: caller must be player");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == custodian.operator(), "Account: caller must be operator");
        _;
    }

    function withdrawETH(uint256 amount) external onlyPlayer {
        uint256 balance = address(this).balance;
        require(amount <= balance, "Account: insufficient balance");
        payable(player).transfer(amount);
    }

    function withdrawTokens(address[] calldata _tokens) external onlyPlayer {
        for (uint i = 0; i < _tokens.length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            token.transfer(msg.sender, balance);
        }
    }

    function withdrawNFTs(address _nft, uint256[] calldata _tokenIds) external onlyPlayer {
        IERC721 nft = IERC721(_nft);
        for (uint i = 0; i < _tokenIds.length; i++) {
            nft.safeTransferFrom(address(this), msg.sender, _tokenIds[i]);
        }
    }

    function swapForGold(address[] calldata _tokens, uint[] calldata _amounts) external onlyPlayer {
        address vender = custodian.DFKVender();
        for (uint i = 0; i < _tokens.length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            uint amount = _amounts[i];
            uint balance = token.balanceOf(address(this));
            require(amount <= balance, "Account: insufficient balance");
            token.approve(vender, amount);
            bytes memory payload = abi.encodeWithSelector(bytes4(0x096c5e1a), _tokens[i], _amounts[i]);
            (bool success,) = vender.call(payload);
            require(success, "Account: sell items failed");
        }
        IERC20 DFKGold = IERC20(custodian.DFKGold());
        uint goldBalance = DFKGold.balanceOf(address(this));
        DFKGold.transfer(player, goldBalance);
    }

    function startQuest(
        uint256[] calldata _heroIds,
        address _questType,
        uint8 _attempts
    ) 
        external
        onlyOperator
    {
        uint256 fee = _heroIds.length * custodian.fee();
        require(address(this).balance >= fee, "Account: insufficent balance");
        require(custodian.questTypes(_questType), "Account: unsupported questType");
        IDFKQuest DFKQuest = IDFKQuest(custodian.DFKQuest());
        DFKQuest.startQuest(_heroIds, _questType, _attempts);
        payable(custodian.admin()).transfer(fee);
    }

    function cancelQuest(uint256 _heroId) external onlyOperator {
        IDFKQuest DFKQuest = IDFKQuest(custodian.DFKQuest());
        DFKQuest.cancelQuest(_heroId);
    }

    function completeQuest(uint256 _heroId) external onlyOperator {
        IDFKQuest DFKQuest = IDFKQuest(custodian.DFKQuest());
        DFKQuest.completeQuest(_heroId);
    }
}
