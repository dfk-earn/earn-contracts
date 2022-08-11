// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NFTBuyingOrder is Ownable, Pausable, ERC721Holder {
    enum OrderStatus { None, Created, Cancelled, Filled }
    struct Order {
        address creator;
        address bidder;
        address nft;
        address paymentToken;
        uint nftId;
        uint price;
        uint createAt;
        uint commission;
        OrderStatus status;
    }

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private supportedPaymentTokens;
    uint public commission; // in bps

    uint public numOrders;
    mapping(uint => Order) public orders;

    event CommissionChanged(uint newCommission, uint oldCommission);
    event PaymentTokenUpdated(address paymentToken, bool add);
    event OrderCreated(uint id, address creator);
    event OrderCancelled(uint id);
    event OrderChanged(uint id);
    event OrderFilled(uint id, address bidder);

    constructor(uint _commission) {
        commission = _commission;
    }

    function create(
        address _nft,
        address _paymentToken,
        uint _price
    )
        external
        whenNotPaused
        returns (uint id)
    {
        require(_price > 0, "NFTBuyingOrder: invalid price");
        require(
            supportedPaymentTokens.contains(_paymentToken),
            "NFTBuyingOrder: invalid paymentToken"
        );

        address creator = msg.sender;
        transferPaymentToken(IERC20(_paymentToken), creator, address(this), _price);
        id = ++numOrders;
        orders[id] = Order({
            creator: creator,
            bidder: address(0),
            nft: _nft,
            paymentToken: _paymentToken,
            nftId: 0,
            price: _price,
            createAt: block.timestamp,
            commission: commission,
            status: OrderStatus.Created
        });
        emit OrderCreated(id, creator);
    }

    function cancel(uint _id) external {
        address creator = msg.sender;
        Order storage order = orders[_id];
        require(order.status == OrderStatus.Created, "NFTBuyingOrder: invalid status");
        require(order.creator == creator, "NFTBuyingOrder: not creator");
        order.status = OrderStatus.Cancelled;
        transferPaymentToken(IERC20(order.paymentToken), address(this), creator, order.price);
        emit OrderCancelled(_id);
    }

    function changePrice(uint _id, uint _newPrice) external {
        Order storage order = orders[_id];
        require(order.status == OrderStatus.Created, "NFTBuyingOrder: invalid status");
        require(order.creator == msg.sender, "NFTBuyingOrder: not creator");
        uint oldPrice = order.price;
        require(_newPrice > 0 && _newPrice != oldPrice, "NFTBuyingOrder: invalid price");
        order.price = _newPrice;
        if (_newPrice > oldPrice) {
            transferPaymentToken(
                IERC20(order.paymentToken),
                order.creator,
                address(this),
                _newPrice - oldPrice
            );
        } else {
            transferPaymentToken(
                IERC20(order.paymentToken),
                address(this),
                order.creator,
                oldPrice - _newPrice
            );
        }
        emit OrderChanged(_id);
    }

    function fill(uint _id, uint _nftId, uint _minPrice) external {
        Order storage order = orders[_id];
        require(order.status == OrderStatus.Created, "NFTBuyingOrder: invalid status");
        require(order.price >= _minPrice, "NFTBuyingOrder: order price less than minPrice");
        address bidder = msg.sender;
        order.bidder = bidder;
        order.nftId = _nftId;
        order.status = OrderStatus.Filled;
        uint fee = order.price * order.commission / 10000;
        transferPaymentToken(IERC20(order.paymentToken), address(this), owner(), fee);
        transferPaymentToken(IERC20(order.paymentToken), address(this), bidder, order.price - fee);
        IERC721(order.nft).safeTransferFrom(bidder, order.creator, _nftId);
        emit OrderFilled(_id, bidder);
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

    function updatePaymentToken(address _paymentToken, bool _add) external onlyOwner {
        if (_add) {
            supportedPaymentTokens.add(_paymentToken);
        } else {
            supportedPaymentTokens.remove(_paymentToken);
        }
        emit PaymentTokenUpdated(_paymentToken, _add);
    }

    function transferPaymentToken(
        IERC20 paymentToken,
        address _from,
        address _to,
        uint _amount
    )
        internal
    {
        if (_from == address(this)) {
            paymentToken.safeTransfer(_to, _amount);
        } else {
            paymentToken.safeTransferFrom(_from, _to, _amount);
        }
    }
}
