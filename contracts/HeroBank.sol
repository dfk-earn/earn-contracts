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

    address public immutable DFKHero;
    uint public immutable MIN_COLLATERAL;
    uint public constant BORROW_LIMIT = 6;

    AuctionHouse public auctionHouse;
    uint public auctionExpiration;

    address public operator;

    uint public maxHeroCount;
    // current hero count in bank
    uint numHeroes;
    // heroId to hero owner address
    mapping(uint256 => address) public heroOwners;
    // owner address to heroId set
    mapping(address => EnumerableSet.UintSet) ownedHeroes;

    uint numBorrows;
    uint[BORROW_LIMIT] borrowedHeroes;

    // Mapping from user address to borrow count
    mapping(address => uint) public userLoans;
    uint public totalLoans;

    event CollateralReceived(address sender, uint256 value);
    event HeroReceived(address indexed from, uint256 tokenId);
    event HeroSent(address indexed to, uint256 tokenId);
    event OperatorChanged(address newOperator, address oldOperator);
    event Claim(address indexed user, uint256 userLoans, uint256 totalLoans);

    constructor(
        uint _maxHeroCount,
        uint _minCollateral,
        address _auctionHouse,
        address _DFKHero
    ) {
        maxHeroCount = _maxHeroCount;
        MIN_COLLATERAL = _minCollateral;
        auctionHouse = AuctionHouse(_auctionHouse);
        auctionExpiration = 1 days;
        DFKHero = _DFKHero;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "HeroBank: not operator");
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
            require(numHeroes <= maxHeroCount, "HeroBank: exceed maxHeroCount");
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
        uint auctionId = auctionHouse.create(_item, _initialPrice, auctionExpiration);
        auctionHouse.money().approve(address(auctionHouse), _initialPrice);
        auctionHouse.bid(auctionId, _initialPrice, msg.sender);
    }

    function getClaimable(address user) public view returns (uint256) {
        return getBalance() * userLoans[user] / totalLoans;
    }

    function claim() external {
        uint claimable = getClaimable(msg.sender);
        require(claimable > 0, "HeroBank: no claimable");
        uint count = userLoans[msg.sender];
        userLoans[msg.sender] = 0;
        totalLoans -= count;
        transferMoney(address(this), msg.sender, claimable);
        emit Claim(msg.sender, count, totalLoans);
    }

    function borrowHeroes(uint[] memory _heroes) external onlyOperator {
        require(numBorrows == 0, "HeroBank: unreturned heroes");
        require(_heroes.length <= BORROW_LIMIT, "HeroBank: exceed BORROW_LIMIT");
        require(address(this).balance >= MIN_COLLATERAL, "HeroBank: not enough margin");
        for (uint i = 0; i < _heroes.length; i++) {
            borrowedHeroes[i] = _heroes[i];
            IERC721(DFKHero).transferFrom(address(this), operator, _heroes[i]);
        }
        numBorrows = _heroes.length;
    }

    function repayHeroes() external onlyOperator {
        require(numBorrows > 0, "HeroBank: no borrowed hero");
        for (uint i = 0; i < numBorrows; i++) {
            uint heroId = borrowedHeroes[i];
            IERC721(DFKHero).transferFrom(operator, address(this), heroId);
            address heroOwner = heroOwners[heroId];
            userLoans[heroOwner] += 1;
            totalLoans += 1;
        }
        numBorrows = 0;
    }

    function withdrawalCollateral() external onlyOwner {
        require(numBorrows == 0, "HeroBank: unreturned heroes");
        Address.sendValue(payable(owner()), address(this).balance);
    }

    function setHeroOwner(uint _heroId, address _owner) external onlyOwner {
        require(IERC721(DFKHero).ownerOf(_heroId) == address(this), "HeroBank: not found");
        require(heroOwners[_heroId] == address(0), "HeroBank: already owned");
        onHeroReceived(_heroId, _owner);
    }

    function setAuctionExpiration(uint _expiration) external onlyOwner {
        auctionExpiration = _expiration;
    }

    function setMaxHeroCount(uint _maxHeroCount) external onlyOwner {
        maxHeroCount = _maxHeroCount;
    }

    function setOperator(address _operator) external onlyOwner {
        address oldOperator = operator;
        operator = _operator;
        emit OperatorChanged(operator, oldOperator);
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

    function getBorrowedHeroes() public view returns (uint[] memory) {
        uint[] memory result = new uint[](numBorrows);
        for (uint i = 0; i < numBorrows; i++) {
            result[i] = borrowedHeroes[i];
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

    function getBalance() public view returns (uint) {
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
}
