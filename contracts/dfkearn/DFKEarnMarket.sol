// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DFKEarnBase.sol";

contract DFKEarnMarket is DFKEarnBase {
    enum OfferStatus { Created, Cancelled, Completed }
    struct Offer {
        address  creator;
        address  bidder;
        address  item;
        uint256  amount;
        uint256  costInJewel;
        uint256  tradingFee; // in bps
        OfferStatus status;
    }

    event TradingFeeChanged(uint256 newValue, uint256 oldValue);
    event OfferCreated(uint256 indexed offerId, address indexed creator, address indexed item, uint256 amount, uint256 costInJewel);
    event OfferCostChanged(uint256 indexed offerId, uint256 costInJewel);
    event OfferCancelled(uint256 indexed offerId, address indexed creator, address indexed item);
    event OfferCompleted(uint256 indexed offerId, address indexed creator, address indexed item, address bidder);

    IERC20 immutable JEWEL;

    uint256 public tradingFee = 250; // in bps

    uint256 public numOffers = 0;
    mapping(uint256 => Offer) public offers;

    constructor(address _accountFactory, address _JEWEL) DFKEarnBase(_accountFactory) {
        JEWEL = IERC20(_JEWEL);
    }

    function createOffer(
        address item,
        uint256 amount,
        uint256 costInJewel
    )
        external
        returns (uint256 offerId)
    {
        require(amount > 0, "DFKEarn: zero amount");
        require(costInJewel > 0, "DFKEarn: zero cost");
        address creator = getAccount(msg.sender);
        uint256 itemBalance = IERC20(item).balanceOf(creator);
        require(itemBalance >= amount, "DFKEarn: insufficient balance");
        IAccount(creator).functionCall(item, abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(this),
            amount
        ));

        offerId = numOffers++;
        offers[offerId] = Offer({
            creator: creator,
            bidder: address(0),
            item: item,
            amount: amount,
            costInJewel: costInJewel,
            tradingFee: tradingFee,
            status: OfferStatus.Created
        });
        emit OfferCreated(offerId, creator, item, amount, costInJewel);
    }

    function cancelOffer(uint256 offerId) external {
        Offer memory offer = offers[offerId];
        require(offer.status == OfferStatus.Created, "DFKEarn: invalid offer status");
        address account = getAccount(msg.sender);
        require(account == offer.creator, "DFKEarn: no permission");
        IERC20(offer.item).transfer(offer.creator, offer.amount);
        offers[offerId].status = OfferStatus.Cancelled;
        emit OfferCancelled(offerId, offer.creator, offer.item);
    }

    function bid(uint256 offerId) external {
        Offer memory offer = offers[offerId];
        require(offer.status == OfferStatus.Created, "DFKEarn: invalid offer status");
        address bidder = msg.sender;
        uint256 cost = offer.costInJewel;
        uint256 jewelBalance = JEWEL.balanceOf(bidder);
        require(jewelBalance >= cost, "DFKEarn: insufficient jewel balance");
        uint256 fee = cost * offer.tradingFee / 10_000;
        JEWEL.transferFrom(bidder, admin, fee);
        JEWEL.transferFrom(bidder, offer.creator, cost - fee);
        IERC20(offer.item).transfer(bidder, offer.amount);
        offers[offerId].bidder = bidder;
        offers[offerId].status = OfferStatus.Completed;
        emit OfferCompleted(offerId, offer.creator, offer.item, bidder);
    }

    function changeOfferCost(uint256 offerId, uint256 _costInJewel) external {
        require(offerId < numOffers, "DFKEarn: invalid offerId");
        Offer memory offer = offers[offerId];
        require(offer.status == OfferStatus.Created, "DFKEarn: invalid offer status");
        address account = getAccount(msg.sender);
        require(account == offer.creator, "DFKEarn: no permission");
        require(_costInJewel > 0, "DFKEarn: zero cost");
        offers[offerId].costInJewel = _costInJewel;
        emit OfferCostChanged(offerId, _costInJewel);
    }

    function setTradingFee(uint256 _tradingFee) external onlyAdmin {
        uint256 oldValue = tradingFee;
        tradingFee = _tradingFee;
        emit TradingFeeChanged(tradingFee, oldValue);
    }
}
