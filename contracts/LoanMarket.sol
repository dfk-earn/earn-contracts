// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Market.sol";

contract LoanMarket is Market {
    enum LoanStatus { None, Created, Cancelled, Rented, Completed, Expired }
    struct Loan {
        address creator;
        address renter;
        Item item;
        uint maxRentDuration;
        uint minRentDuration;
        uint itemValue;
        uint dailyRentPrice;
        uint commission;
        uint payment;
        uint rentAt;
        uint expiredAt;
        LoanStatus status;
    }

    uint private constant DAY = 86400;

    uint public numLoans;
    mapping(uint => Loan) public loans;

    event Created(uint indexed id, address indexed creator);
    event Cancelled(uint indexed id);
    event Rented(uint indexed id, address renter);
    event Completed(uint indexed id);
    event Expired(uint indexed id);
    event RentPriceChanged(uint indexed id);
    event ItemValueChanged(uint indexed id);

    constructor(address _money, uint _commission) Market(_money, _commission) {}

    function create(
        Item calldata _item,
        uint _maxRentDuration,
        uint _minRentDuration,
        uint _itemValue,
        uint _dailyRentPrice
    )
        external
        whenNotPaused
        returns (uint id)
    {
        require(_itemValue > 0, "LoanMarket: zero itemValue");
        require(_maxRentDuration > 0, "LoanMarket: zero maxRentDuration");
        require(
            _minRentDuration <= _maxRentDuration,
            "LoanMarket: minRentDuration greater than maxRentDuration"
        );
        address creator = msg.sender;
        transferItem(creator, address(this), _item);
        id = ++numLoans;
        loans[id] = Loan({
            creator: creator,
            renter: address(0),
            item: _item,
            maxRentDuration: _maxRentDuration,
            minRentDuration: _minRentDuration,
            itemValue: _itemValue,
            dailyRentPrice: _dailyRentPrice,
            commission: commission,
            payment: 0,
            rentAt: 0,
            expiredAt: 0,
            status: LoanStatus.Created
        });
        emit Created(id, creator);
    }

    function cancel(uint _id) external {
        address creator = msg.sender;
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Created, "LoanMarket: invalid status");
        require(loan.creator == creator, "LoanMarket: not creator");
        loan.status = LoanStatus.Cancelled;
        transferItem(address(this), creator, loan.item);
        emit Cancelled(_id);
    }

    function changeRentPrice(uint _id, uint _dailyRentPrice) external {
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Created, "LoanMarket: invalid status");
        require(loan.creator == msg.sender, "LoanMarket: not creator");
        loan.dailyRentPrice = _dailyRentPrice;
        emit RentPriceChanged(_id);
    }

    function changeItemValue(uint _id, uint _itemValue) external {
        require(_itemValue > 0, "LoanMarket: zero itemValue");
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Created, "LoanMarket: invalid status");
        require(loan.creator == msg.sender, "LoanMarket: not creator");
        loan.itemValue = _itemValue;
        emit ItemValueChanged(_id);
    }

    function rent(uint _id, uint _rentDuration) external {
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Created, "LoanMarket: invalid status");
        require(
            _rentDuration >= loan.minRentDuration && _rentDuration <= loan.maxRentDuration,
            "loadMarket: invalid rentDuration"
        );
        address renter = msg.sender;
        loan.renter = renter;
        loan.payment = loan.itemValue + loan.dailyRentPrice * _rentDuration / DAY;
        loan.rentAt = block.timestamp;
        loan.expiredAt = block.timestamp + _rentDuration;
        loan.status = LoanStatus.Rented;
        transferMoney(renter, address(this), loan.payment);
        transferItem(address(this), renter, loan.item);
        emit Rented(_id, renter);
    }

    function repay(uint _id) external {
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Rented, "LoanMarket: invalid status");
        require(block.timestamp <= loan.expiredAt, "LoanMarket: expired");
        address renter = msg.sender;
        require(renter == loan.renter, "LoanMarket: not renter");
        transferItem(renter, loan.creator, loan.item);
        loan.status = LoanStatus.Completed;
        uint rentDuration = max(block.timestamp - loan.rentAt, loan.minRentDuration);
        uint cost = loan.dailyRentPrice * rentDuration / DAY;
        transferMoney(address(this), renter, loan.payment - cost);
        uint fee = cost * loan.commission / 10000;
        transferMoney(address(this), payable(owner()), fee);
        transferMoney(address(this), payable(loan.creator), cost - fee);
        emit Completed(_id);
    }

    function settle(uint _id) external {
        Loan storage loan = loans[_id];
        require(loan.status == LoanStatus.Rented, "LoanMarket: invalid status");
        require(block.timestamp > loan.expiredAt, "LoanMarket: unexpired");
        loan.status = LoanStatus.Expired;
        uint fee = (loan.payment - loan.itemValue) * loan.commission / 10000;
        transferMoney(address(this), payable(owner()), fee);
        transferMoney(address(this), payable(loan.creator), loan.payment - fee);
        emit Expired(_id);
    }

    function max(uint a, uint b) private pure returns (uint) {
        return a >= b ? a : b;
    }
}
