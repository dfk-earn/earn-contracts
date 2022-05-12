// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Market.sol";

contract FixedPriceMarket is Market {
    enum OfferStatus { None, Created, Cancelled, Completed }
    struct Offer {
        address creator;
        address bidder;
        Item item;
        uint price;
        uint commission;    // in bps
        OfferStatus status;
    }

    event Created(uint indexed id, address indexed creator);
    event PriceChanged(uint indexed id);
    event Cancelled(uint indexed id);
    event Completed(uint indexed id, address bidder);

    uint public numOffers;
    mapping(uint => Offer) public offers;

    constructor(address _money, uint _commission) Market(_money, _commission) {}

    function create(
        Item calldata _item,
        uint _price
    )
        external
        whenNotPaused
        returns (uint id)
    {
        require(_price > 0, "Market: zero price");
        address creator = msg.sender;
        transferItem(creator, address(this), _item);
        id = ++numOffers;
        offers[id] = Offer({
            creator: creator,
            bidder: address(0),
            item: _item,
            price: _price,
            commission: commission,
            status: OfferStatus.Created
        });
        emit Created(id, creator);
    }

    function cancel(uint _id) external {
        address creator = msg.sender;
        Offer memory offer = offers[_id];
        require(offer.status == OfferStatus.Created, "Market: invalid offer status");
        require(offer.creator == creator, "Market: not creator");
        transferItem(address(this), creator, offer.item);
        offers[_id].status = OfferStatus.Cancelled;
        emit Cancelled(_id);
    }

    function bid(uint _id) external {
        Offer memory offer = offers[_id];
        require(offer.status == OfferStatus.Created, "Market: invalid offer status");
        address bidder = msg.sender;
        uint fee = offer.price * offer.commission / 10000;
        transferMoney(bidder, owner(), fee);
        transferMoney(bidder, offer.creator, offer.price - fee);
        transferItem(address(this), bidder, offer.item);
        offers[_id].bidder = bidder;
        offers[_id].status = OfferStatus.Completed;
        emit Completed(_id, bidder);
    }

    function changePrice(uint _id, uint _price) external {
        require(_price > 0, "Market: zero price");
        address creator = msg.sender;
        Offer memory offer = offers[_id];
        require(offer.status == OfferStatus.Created, "Market: invalid offer status");
        require(offer.creator == creator, "Market: not creator");
        offers[_id].price = _price;
        emit PriceChanged(_id);
    }
}
