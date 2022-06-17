// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AuctionHouse.sol";

contract HeroBank is Ownable, Pausable, IERC721Receiver, ERC1155Holder {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable DFKHero;
    uint public immutable COLLATERAL_PER_OPERATOR;
    uint public constant BORROW_LIMIT_PER_OPERATOR = 6;

    AuctionHouse public auctionHouse;
    uint public auctionExpiration;
    uint public auctionRenewPeriod;

    EnumerableSet.AddressSet private operators;
    uint public numActiveOperators = 0;

    struct BorrowInfo {
        uint numBorrows;
        uint[BORROW_LIMIT_PER_OPERATOR] borrowedHeroes;
    }
    // operator address to borrow info
    mapping(address => BorrowInfo) public borrowInfos;

    // current hero count in bank
    uint numHeroes;
    // heroId to hero owner address
    mapping(uint256 => address) public heroOwners;
    // owner address to heroId set
    mapping(address => EnumerableSet.UintSet) ownedHeroes;

    // Mapping from user address to borrow count
    mapping(address => uint) public userScores;
    uint public totalScore;

    event CollateralReceived(address sender, uint256 value);
    event OperatorUpdated(address operator, bool add);
    event HeroReceived(address indexed from, uint256 tokenId);
    event HeroSent(address indexed to, uint256 tokenId);
    event OperatorChanged(address newOperator, address oldOperator);
    event UserClaimed(address indexed user, uint256 value);

    constructor(
        address _DFKHero,
        address _auctionHouse,
        uint _collateralPerOperator
    ) {
        DFKHero = _DFKHero;
        auctionHouse = AuctionHouse(_auctionHouse);
        COLLATERAL_PER_OPERATOR = _collateralPerOperator;
        auctionExpiration = 1 days;
        auctionRenewPeriod = 2 hours;
    }

    modifier onlyOperator() {
        require(operators.contains(msg.sender), "HeroBank: not operator");
        _;
    }

    receive() external payable {
        emit CollateralReceived(msg.sender, msg.value);
    }

    function onERC721Received(
        address /* _operator */,
        address _from,
        uint256 _tokenId,
        bytes calldata /* _data */
    )
        external
        override
        whenNotPaused
        returns (bytes4)
    {
        if (msg.sender == DFKHero) {
            assert(heroOwners[_tokenId] == address(0));
            onHeroReceived(_tokenId, _from);
        }
        return this.onERC721Received.selector;
    }

    function withdrawalHeroes(uint[] calldata _heroes) external {
        for (uint i = 0; i < _heroes.length; i++) {
            uint heroId = _heroes[i];
            address heroOwner = heroOwners[heroId];
            require(msg.sender == heroOwner, "HeroBank: not hero owner");
            IERC721(DFKHero).safeTransferFrom(address(this), heroOwner, heroId);
            onHeroSent(heroId, heroOwner);
        }
    }

    function createAuctionAndBid(Item calldata _item, uint256 _initialPrice) external {
        transferMoney(msg.sender, address(this), _initialPrice);
        uint auctionId = auctionHouse.create(
            _item,
            _initialPrice,
            auctionExpiration,
            auctionRenewPeriod
        );
        auctionHouse.money().approve(address(auctionHouse), _initialPrice);
        auctionHouse.bid(auctionId, _initialPrice, msg.sender);
    }

    function getClaimable(address user) public view returns (uint256) {
        return getRealizedProfit() * userScores[user] / totalScore;
    }

    function claim() external {
        address user = msg.sender;
        uint claimable = getClaimable(user);
        require(claimable > 0, "HeroBank: no claimable");
        uint score = userScores[user];
        userScores[user] = 0;
        totalScore -= score;
        transferMoney(address(this), user, claimable);
        emit UserClaimed(user, claimable);
    }

    function borrowHeroes(uint[] memory _heroes) external onlyOperator {
        address operator = msg.sender;
        BorrowInfo storage borrowInfo = borrowInfos[operator];
        require(borrowInfo.numBorrows == 0, "HeroBank: unreturned heroes");
        require(
            availableCollateral() >= COLLATERAL_PER_OPERATOR,
            "HeroBank: insufficient collateral"
        );
        require(
            _heroes.length <= BORROW_LIMIT_PER_OPERATOR,
            "HeroBank: exceed BORROW_LIMIT"
        );
        for (uint i = 0; i < _heroes.length; i++) {
            borrowInfo.borrowedHeroes[i] = _heroes[i];
            IERC721(DFKHero).transferFrom(address(this), operator, _heroes[i]);
        }
        borrowInfo.numBorrows = _heroes.length;
        numActiveOperators++;
    }

    function repayHeroes() external onlyOperator {
        address operator = msg.sender;
        BorrowInfo storage borrowInfo = borrowInfos[operator];
        require(borrowInfo.numBorrows > 0, "HeroBank: no borrow info");
        for (uint i = 0; i < borrowInfo.numBorrows; i++) {
            uint heroId = borrowInfo.borrowedHeroes[i];
            IERC721(DFKHero).transferFrom(operator, address(this), heroId);
            address heroOwner = heroOwners[heroId];
            userScores[heroOwner] += 1;
            totalScore += 1;
        }
        borrowInfo.numBorrows = 0;
        numActiveOperators--;
    }

    function withdrawalCollateral() external onlyOwner {
        Address.sendValue(payable(owner()), availableCollateral());
    }

    function setHeroOwner(uint _heroId, address _owner) external onlyOwner {
        require(IERC721(DFKHero).ownerOf(_heroId) == address(this), "HeroBank: not found");
        require(heroOwners[_heroId] == address(0), "HeroBank: already owned");
        onHeroReceived(_heroId, _owner);
    }

    function setAuctionExpiration(uint _expiration) external onlyOwner {
        auctionExpiration = _expiration;
    }

    function setAuctionRenewPeriod(uint _renewPeriod) external onlyOwner {
        auctionRenewPeriod = _renewPeriod;
    }

    function updateOperator(address _operator, bool _add) external onlyOwner {
        if (_add) {
            operators.add(_operator);
        } else {
            require(
                borrowInfos[_operator].numBorrows == 0,
                "HeroBank: unreturned heroes"
            );
            delete borrowInfos[_operator];
            operators.remove(_operator);
        }
        emit OperatorUpdated(_operator, _add);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function approveItem(
        address _itemAddr,
        ItemType _itemType,
        bool _approved
    )
        external
        onlyOwner
    {
        if (_itemType == ItemType.ERC20) {
            uint amount = _approved ? type(uint).max : 0;
            IERC20(_itemAddr).approve(address(auctionHouse), amount);
        } else if (_itemType == ItemType.ERC721) {
            IERC721(_itemAddr).setApprovalForAll(address(auctionHouse), _approved);
        } else if (_itemType == ItemType.ERC1155) {
            IERC1155(_itemAddr).setApprovalForAll(address(auctionHouse), _approved);
        }
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

    function getHeroesOfOwner(address _owner) public view returns (uint[] memory) {
        EnumerableSet.UintSet storage heroes = ownedHeroes[_owner];
        uint length = heroes.length();
        uint[] memory result = new uint[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = heroes.at(i);
        }
        return result;
    }

    function getRealizedProfit() public view returns (uint) {
        return auctionHouse.money().balanceOf(address(this));
    }

    function onHeroReceived(uint _heroId, address _owner) private {
        heroOwners[_heroId] = _owner;
        ownedHeroes[_owner].add(_heroId);
        numHeroes++;
        emit HeroReceived(_owner, _heroId);
    }

    function onHeroSent(uint _heroId, address _owner) private {
        delete heroOwners[_heroId];
        ownedHeroes[_owner].remove(_heroId);
        numHeroes--;
        emit HeroSent(_owner, _heroId);
    }

    function transferMoney(address _from, address _to, uint _amount) private {
        if (_from == address(this)) {
            auctionHouse.money().safeTransfer(_to, _amount);
        } else {
            auctionHouse.money().safeTransferFrom(_from, _to, _amount);
        }
    }

    function availableCollateral() private view returns (uint) {
        return address(this).balance - numActiveOperators * COLLATERAL_PER_OPERATOR;
    }
}
