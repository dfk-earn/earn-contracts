// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAccount.sol";

contract PrivateHeroBank is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable DFKHero;
    address public immutable DFKJewel;
    uint public immutable COLLATERAL_PER_OPERATOR;
    uint public constant BORROW_LIMIT_PER_OPERATOR = 6;
    uint public constant MAX_BORROW_DURATION = 3 days;

    EnumerableSet.AddressSet private operators;
    uint public numActiveOperators = 0;

    uint public feePerHero;

    mapping(address => uint) public accountScores;
    uint public totalScore;

    struct BorrowInfo {
        address account;
        uint timestamp;
        uint numBorrows;
        uint[BORROW_LIMIT_PER_OPERATOR] borrowedHeroes;
    }
    // operator address to borrow info
    mapping(address => BorrowInfo) public borrowInfos;

    event CollateralReceived(address sender, uint256 value);
    event CompensationClaimed(address indexed account, uint256 value);
    event AccountClaimed(address indexed account, uint256 value);
    event OperatorUpdated(address operator, bool add);

    constructor(
        address _DFKHero,
        address _DFKJewel,
        uint _collateralPerOperator
    ) {
        DFKHero = _DFKHero;
        DFKJewel = _DFKJewel;
        COLLATERAL_PER_OPERATOR = _collateralPerOperator;
        feePerHero = 0.09 ether;
    }

    modifier onlyOperator() {
        require(operators.contains(msg.sender), "PrivateHeroBank: not operator");
        _;
    }

    receive() external payable {
        emit CollateralReceived(msg.sender, msg.value);
    }

    function claimCompensation() external {
        uint n = 0;
        uint length = operators.length();
        for (uint i = 0; i < length; i++) {
            BorrowInfo storage info = borrowInfos[operators.at(i)];
            if (info.numBorrows > 0 && info.account == msg.sender
                    && block.timestamp > info.timestamp + MAX_BORROW_DURATION) {
                n++;
                info.numBorrows = 0;
                numActiveOperators--;
            }
        }
        require(n > 0, "PrivateHeroBank: no claimable compensation");
        uint compensation = n * COLLATERAL_PER_OPERATOR;
        Address.sendValue(payable(msg.sender), compensation);
        emit CompensationClaimed(msg.sender, compensation);
    }

    function getClaimableJewel(address _account) public view returns (uint256) {
        uint balance = IERC20(DFKJewel).balanceOf(address(this));
        require(balance > 0, "PrivateHeroBank: zero jewel balance");
        return balance * accountScores[_account] / totalScore;
    }

    function claimJewel() external {
        address account = msg.sender;
        uint claimable = getClaimableJewel(account);
        require(claimable > 0, "PrivateHeroBank: no claimable jewel");
        uint score = accountScores[account];
        accountScores[account] = 0;
        totalScore -= score;
        IERC20(DFKJewel).safeTransfer(account, claimable);
        emit AccountClaimed(account, claimable);
    }

    function borrowHeroes(
        address _account,
        uint[] memory _heroes
    )
        external
        onlyOperator
    {
        address operator = msg.sender;
        BorrowInfo storage borrowInfo = borrowInfos[operator];
        require(borrowInfo.numBorrows == 0, "PrivateHeroBank: unreturned heroes");
        require(
            availableCollateral() >= COLLATERAL_PER_OPERATOR,
            "PrivateHeroBank: insufficient collateral"
        );
        require(
            _heroes.length <= BORROW_LIMIT_PER_OPERATOR,
            "PrivateHeroBank: exceed BORROW_LIMIT"
        );
        uint questFee = _heroes.length * feePerHero;
        require(_account.balance >= questFee, "PrivateHeroBank: insufficent balance for quest");
        IAccount(_account).sendValue(payable(owner()), questFee);

        for (uint i = 0; i < _heroes.length; i++) {
            borrowInfo.borrowedHeroes[i] = _heroes[i];
            IAccount(_account).functionCall(DFKHero, abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                _account,
                operator,
                _heroes[i]
            ));
        }
        borrowInfo.account = _account;
        borrowInfo.numBorrows = _heroes.length;
        numActiveOperators++;
        borrowInfo.timestamp = block.timestamp;
    }

    function repayHeroes() external onlyOperator {
        address operator = msg.sender;
        BorrowInfo storage borrowInfo = borrowInfos[operator];
        require(borrowInfo.numBorrows > 0, "PrivateHeroBank: no borrow info");
        for (uint i = 0; i < borrowInfo.numBorrows; i++) {
            uint heroId = borrowInfo.borrowedHeroes[i];
            IERC721(DFKHero).transferFrom(operator, borrowInfo.account, heroId);
            accountScores[borrowInfo.account] += 1;
            totalScore += 1;
        }
        borrowInfo.numBorrows = 0;
        numActiveOperators--;
    }

    function withdrawalCollateral() external onlyOwner {
        Address.sendValue(payable(owner()), availableCollateral());
    }

    function setFeePerHero(uint _feePerHero) external onlyOwner {
        feePerHero = _feePerHero;
    }

    function updateOperator(address _operator, bool _add) external onlyOwner {
        if (_add) {
            operators.add(_operator);
        } else {
            require(
                borrowInfos[_operator].numBorrows == 0,
                "PrivateHeroBank: unreturned heroes"
            );
            delete borrowInfos[_operator];
            operators.remove(_operator);
        }
        emit OperatorUpdated(_operator, _add);
    }

    function getBorrowedHeroes(address _operator) public view returns (uint[] memory) {
        BorrowInfo storage borrowInfo = borrowInfos[_operator];
        uint numBorrows = borrowInfo.numBorrows;
        uint[] memory result = new uint[](numBorrows);
        for (uint i = 0; i < numBorrows; i++) {
            result[i] = borrowInfo.borrowedHeroes[i];
        }
        return result;
    }

    function getOperators() public view returns (address[] memory) {
        uint length = operators.length();
        address[] memory result = new address[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = operators.at(i);
        }
        return result;
    }

    function availableCollateral() private view returns (uint) {
        return address(this).balance - numActiveOperators * COLLATERAL_PER_OPERATOR;
    }
}
