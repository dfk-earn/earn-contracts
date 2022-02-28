const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");

const JewelScale = ethers.BigNumber.from(10).pow(18);

describe.only("DFKEarnMarket", function() {
    let DFKEarnMarket;
    let MockItem;
    let MockJewel
    let seller, sellerAccount;
    let buyer, buyerAccount;
    let offer;

    beforeEach(async function() {
        await deployments.fixture(["DFKEarnMarket", "AccountFactory", "mocks" ]);
        DFKEarnMarket = await ethers.getContract("DFKEarnMarket");
        MockItem = await ethers.getContract("MockItem");
        MockJewel = await ethers.getContract("MockJewel");

        const AccountFactory = await ethers.getContract("AccountFactory");
        const unnamed = await getUnnamedAccounts();

        // create seller and sellerAccount
        seller = await ethers.getSigner(unnamed[0]);
        let tx = await AccountFactory.connect(seller).createAccountWithWhitelist([ DFKEarnMarket.address ]);
        await tx.wait();
        sellerAccount = await AccountFactory.accounts(seller.address);
        // mint 10 MockItem and deposit to sellerAccount
        MockItem = await ethers.getContract("MockItem", seller);
        tx = await MockItem.mint(10);
        await tx.wait();
        const itemBalance = await MockItem.balanceOf(seller.address);
        tx = await MockItem.transfer(sellerAccount, itemBalance);
        await tx.wait();

        // create buyer and buyerAccount
        buyer = await ethers.getSigner(unnamed[1]);
        tx = await AccountFactory.connect(buyer).createAccountWithWhitelist([ DFKEarnMarket.address ]);
        await tx.wait();
        buyerAccount = await AccountFactory.accounts(buyer.address);
        // mint 100 MockJewel
        MockJewel = await ethers.getContract("MockJewel", buyer);
        tx = await MockJewel.mint(JewelScale.mul(300));
        await tx.wait();

        // create an offer
        tx = await DFKEarnMarket.connect(seller).createOffer(
            MockItem.address,
            10,
            JewelScale.mul(100)
        );
        await tx.wait();
        offer = await DFKEarnMarket.offers(0);
    })

    it("should create an offer", async function() {
        const numOffers = await DFKEarnMarket.numOffers();
        expect(numOffers).to.eq(1);
        expect(offer.creator).to.eq(sellerAccount);
        expect(offer.item).to.eq(MockItem.address);
        expect(offer.amount).to.eq(10);
        expect(offer.costInJewel).to.eq(JewelScale.mul(100));
        expect(offer.status).to.eq(0);
        const itemBalanceOfSellerAccount = await MockItem.balanceOf(sellerAccount);
        expect(itemBalanceOfSellerAccount).to.eq(0);
        const itemBalanceOfContract = await MockItem.balanceOf(DFKEarnMarket.address);
        expect(itemBalanceOfContract).to.eq(10);
    })

    it("should cancel an offer", async function() {
        const tx = await DFKEarnMarket.connect(seller).cancelOffer(0);
        await tx.wait();
        offer = await DFKEarnMarket.offers(0);
        expect(offer.status).to.eq(1);
        const itemBalanceOfSellerAccount = await MockItem.balanceOf(sellerAccount);
        expect(itemBalanceOfSellerAccount).to.eq(10);
        const itemBalanceOfContract = await MockItem.balanceOf(DFKEarnMarket.address);
        expect(itemBalanceOfContract).to.eq(0);
    })

    it("should bid an offer", async function() {
        const cost = offer.costInJewel;
        let tx = await MockJewel.connect(buyer).approve(DFKEarnMarket.address, cost);
        await tx.wait();
        tx = await DFKEarnMarket.connect(buyer).bid(0);
        await tx.wait();
        offer = await DFKEarnMarket.offers(0);
        expect(offer.status).to.eq(2);
        expect(offer.bidder).to.eq(buyer.address);
        const itemBalanceOfSellerAccount = await MockItem.balanceOf(sellerAccount);
        expect(itemBalanceOfSellerAccount).to.eq(0);
        const itemBalanceOfBuyer = await MockItem.balanceOf(buyer.address);
        expect(itemBalanceOfBuyer).to.eq(10);
        const tradingFeeInBPS = await DFKEarnMarket.tradingFee();
        const fee = cost.mul(tradingFeeInBPS).div(10000);
        const admin = await DFKEarnMarket.admin();
        const jewelBalanceOfAdmin = await MockJewel.balanceOf(admin);
        expect(jewelBalanceOfAdmin).to.eq(fee);
        const jewelBalanceOfSeller = await MockJewel.balanceOf(sellerAccount);
        expect(jewelBalanceOfSeller).to.eq(cost.sub(fee));
        const JewelBalanceOfBuyer = await MockJewel.balanceOf(buyer.address);
        expect(JewelBalanceOfBuyer).to.eq(JewelScale.mul(200));
    })

    it("should change offer cost", async function() {
        const newCost = JewelScale.mul(200);
        const tx = await DFKEarnMarket.connect(seller).changeOfferCost(0, newCost);
        await tx.wait();
        offer = await DFKEarnMarket.offers(0);
        expect(offer.status).to.eq(0);
        expect(offer.costInJewel).to.eq(newCost);
    })
});
