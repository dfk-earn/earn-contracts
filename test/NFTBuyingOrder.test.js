const {
    getNamedAccounts,
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");

const JewelScalar = ethers.BigNumber.from(10).pow(18);
const Price = JewelScalar.mul(200);

describe.only("NFTBuyingOrder", function() {
    let NFTBuyingOrder;
    let MockJewel;
    let MockERC721;
    let creator, initialCreatorBalance;
    let bidder;
    let tx;

    beforeEach(async function() {
        await deployments.fixture([ "NFTBuyingOrder", "Mocks" ]);
        NFTBuyingOrder = await ethers.getContract("NFTBuyingOrder");
        MockJewel = await ethers.getContract("MockJewel");
        MockERC721 = await ethers.getContract("MockHero");

        tx = await NFTBuyingOrder.updatePaymentToken(MockJewel.address, true);
        await tx.wait();

        const unnamed = await getUnnamedAccounts();
        creator = await ethers.getSigner(unnamed[0]);
        bidder = await ethers.getSigner(unnamed[1]);

        initialCreatorBalance = JewelScalar.mul(1000);
        tx = await MockJewel.connect(creator).mint(creator.address, initialCreatorBalance);
        await tx.wait();
        tx = await MockJewel.connect(creator).approve(
            NFTBuyingOrder.address,
            ethers.constants.MaxUint256
        );
        await tx.wait();

        tx = await MockERC721.connect(bidder).mint(bidder.address, 100);
        await tx.wait();
        tx = await MockERC721.connect(bidder).setApprovalForAll(NFTBuyingOrder.address, true);
        await tx.wait();
    })

    it("should create a buying order", async function() {
        const id = await createBuyingOrder(Price);

        let currentCreatorBalance = await MockJewel.balanceOf(creator.address);
        expect(currentCreatorBalance).to.eq(initialCreatorBalance.sub(Price));

        const price1 = Price.mul(2);        
        tx = await NFTBuyingOrder.connect(creator).changePrice(id, price1);
        await tx.wait();
        currentCreatorBalance = await MockJewel.balanceOf(creator.address);
        expect(currentCreatorBalance).to.eq(initialCreatorBalance.sub(price1));

        const price2 = price1.div(2);        
        tx = await NFTBuyingOrder.connect(creator).changePrice(id, price2);
        await tx.wait();
        currentCreatorBalance = await MockJewel.balanceOf(creator.address);
        expect(currentCreatorBalance).to.eq(initialCreatorBalance.sub(price2));
    })

    it("should cancel an order", async function() {
        const id = await createBuyingOrder(Price);        
        tx = await NFTBuyingOrder.connect(creator).cancel(id);
        await tx.wait();

        const currentCreatorBalance = await MockJewel.balanceOf(creator.address);
        expect(currentCreatorBalance).to.eq(initialCreatorBalance);
    })

    it("should fill an order", async function() {
        const id1 = await createBuyingOrder(Price);
        const tokenId = 3;
        tx = await NFTBuyingOrder.connect(bidder).fill(id1, tokenId, Price);
        await tx.wait();

        const { commission } = await NFTBuyingOrder.orders(id1);
        const protocolFee = Price.mul(commission).div(10000);
        const currentBidderBalance = await MockJewel.balanceOf(bidder.address);
        expect(currentBidderBalance).to.eq(Price.sub(protocolFee));

        const nftOwner = await MockERC721.ownerOf(3);
        expect(nftOwner).to.eq(creator.address);
    })

    async function createBuyingOrder(price) {
        const tx = await NFTBuyingOrder.connect(creator).create(
            MockERC721.address,
            MockJewel.address,
            price,
        );
        await tx.wait();
        return await NFTBuyingOrder.numOrders();
    }
});
