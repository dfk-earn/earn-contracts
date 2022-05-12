// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Market.sol";

contract AuctionHouse is Market {
    enum AuctionStatus { None, Created, Cancelled, Bidding, Completed }
    struct Auction {
        address creator;
        address bidder;
        Item item;
        uint minPrice;
        uint currentPrice;
        uint expiration;
        uint deadline;
        uint commission;
        AuctionStatus status;
    }

    uint public tickSize;
    uint public minExpiration;
    uint public maxExpiration;

    uint public numAuctions;
    mapping(uint => Auction) public auctions;

    event Created(uint indexed id, address indexed creator);
    event MinPriceChanged(uint indexed id);
    event Cancelled(uint indexed id);
    event NewBidder(uint indexed id, address bidder);
    event Completed(uint indexed id, address winner);

    constructor(
        address _money,
        uint _commission,
        uint _tickSize
    )
        Market(_money, _commission)
    {
        tickSize = _tickSize;
        minExpiration = 1 hours;
        maxExpiration = 10 days;
    }

    function create(
        Item calldata _item,
        uint _minPrice,
        uint _expiration
    )
        external
        whenNotPaused
        returns (uint id)
    {
        uint minPrice = roundDownPrice(_minPrice);
        require(minPrice > 0, "AuctionHouse: zero minPrice");
        require(
            _expiration >= minExpiration && _expiration <= maxExpiration,
            "AuctionHouse: invalid expiration"
        );

        address creator = msg.sender;
        transferItem(creator, address(this), _item);
        id = ++numAuctions;
        auctions[id] = Auction({
            creator: creator,
            bidder: address(0),
            item: _item,
            minPrice: minPrice,
            currentPrice: 0,
            expiration: _expiration,
            deadline: 0,
            commission: commission,
            status: AuctionStatus.Created
        });
        emit Created(id, creator);
    }

    function cancel(uint _id) external {
        Auction memory auction = auctions[_id];
        require(auction.status == AuctionStatus.Created, "AuctionHouse: invalid auction status");
        address creator = msg.sender;
        require(auction.creator == creator, "AuctionHouse: not creator");
        transferItem(address(this), creator, auction.item);
        auctions[_id].status = AuctionStatus.Cancelled;
        emit Cancelled(_id);
    }

    function changeMinPrice(uint _id, uint _minPrice) external {
        uint minPrice = roundDownPrice(_minPrice);
        require(minPrice > 0, "AuctionHouse: zero minPrice");
        address creator = msg.sender;
        Auction memory auction = auctions[_id];
        require(auction.status == AuctionStatus.Created, "AuctionHouse: invalid offer status");
        require(auction.creator == creator, "AuctionHouse: not creator");
        auctions[_id].minPrice = minPrice;
        emit MinPriceChanged(_id);
    }

    function bid(uint256 _id, uint256 _price, address _beneficiary) external {
        require(isAuctionActive(_id), "AuctionHouse: auction not active");
        Auction memory auction = auctions[_id];
        address committer = msg.sender;
        address bidder = msg.sender;
        if (_beneficiary != address(0)) {
            bidder = _beneficiary;
        }

        uint price = roundDownPrice(_price);
        if (auction.status == AuctionStatus.Created) {
            require(price >= auction.minPrice, "AuctionHouse: invalid price");
        } else {
            require(price > auction.currentPrice, "AuctionHouse: invalid price");
            transferMoney(address(this), auction.bidder, auction.currentPrice);
        }

        transferMoney(committer, address(this), price);
        auctions[_id].bidder = bidder;
        auctions[_id].currentPrice = price;
        auctions[_id].deadline = block.timestamp + auction.expiration;
        auctions[_id].status = AuctionStatus.Bidding;
        emit NewBidder(_id, bidder);
    }

    function complete(uint _id) external {
        require(isAuctionEnd(_id), "AuctionHouse: auction not end");
        Auction memory auction = auctions[_id];
        uint finalPrice = auction.currentPrice;
        uint fee = finalPrice * auction.commission / 10000;
        transferMoney(address(this), owner(), fee);
        transferMoney(address(this), auction.creator, finalPrice - fee);
        transferItem(address(this), auction.bidder, auction.item);
        auctions[_id].status = AuctionStatus.Completed;
        emit Completed(_id, auction.bidder);
    }

    function setTickSize(uint _tickSize) external onlyOwner {
        tickSize = _tickSize;
    }

    function setMinExpiration(uint _minExpiration) external onlyOwner {
        minExpiration = _minExpiration;
    }

    function setMaxExpiration(uint _maxExpiration) external onlyOwner {
        maxExpiration = _maxExpiration;
    }

    function isAuctionActive(uint _id) public view returns (bool) {
        Auction memory auction = auctions[_id];
        return (auction.status == AuctionStatus.Created) ||
            (auction.status == AuctionStatus.Bidding && block.timestamp <= auction.deadline);
    }

    function isAuctionEnd(uint _id) public view returns (bool) {
        Auction memory auction = auctions[_id];
        return auction.status == AuctionStatus.Bidding && block.timestamp > auction.deadline;
    }

    function roundDownPrice(uint _price) private view returns (uint) {
        return _price / tickSize * tickSize;
    }
}
