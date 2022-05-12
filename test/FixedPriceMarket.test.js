const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");

const JewelScale = ethers.BigNumber.from(10).pow(18);

describe("FixedPriceMarket", function() {
    let FixedPriceMarket;
    let MockJewel;
    let seller;
    let buyer;
    let commission;
    let tx;

    beforeEach(async function() {
        await deployments.fixture(["FixedPriceMarket", "AccountFactory", "Mocks" ]);
        FixedPriceMarket = await ethers.getContract("FixedPriceMarket");
        commission = await FixedPriceMarket.commission();
        MockJewel = await ethers.getContract("MockJewel");
        MockERC20 = await ethers.getContract("MockERC20");
        MockERC721 = await ethers.getContract("MockHero");
        MockERC1155 = await ethers.getContract("MockERC1155");

        const unnamed = await getUnnamedAccounts();
        seller = await ethers.getSigner(unnamed[0]);
        buyer = await ethers.getSigner(unnamed[1]);

        const jewelBalance = JewelScale.mul(100);
        tx = await MockJewel.connect(buyer).mint(buyer.address, jewelBalance);
        await tx.wait();
        tx = await MockJewel.connect(buyer).approve(FixedPriceMarket.address, jewelBalance);
        await tx.wait();
    })

    it("should swap an erc20 item", async function() {
        const itemAmount = 100;
        const itemPrice = JewelScale.mul(30);
        const offerId = await createOffer({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        }, itemPrice);

        tx = await FixedPriceMarket.connect(buyer).bid(offerId);
        await tx.wait();

        const sellerBalance = await MockJewel.balanceOf(seller.address);
        const fee = itemPrice.mul(commission).div(10000);
        expect(sellerBalance).to.eq(itemPrice.sub(fee));

        const buyerItemBalance = await MockERC20.balanceOf(buyer.address);
        expect(buyerItemBalance).to.eq(itemAmount);
    })

    it("should swap an erc721 item", async function() {
        const ids = [ 1, 2, 3 ];
        const itemPrice = JewelScale.mul(30);
        const offerId = await createOffer({
            itemType: 1,
            addr: MockERC721.address,
            amounts: [ ],
            ids: ids
        }, itemPrice);

        tx = await FixedPriceMarket.connect(buyer).bid(offerId);
        await tx.wait();

        const sellerBalance = await MockJewel.balanceOf(seller.address);
        const fee = itemPrice.mul(commission).div(10000);
        expect(sellerBalance).to.eq(itemPrice.sub(fee));

        for (let i = 0; i < ids.length; i++) {
            const owner = await MockERC721.ownerOf(ids[i]);
            expect(owner).to.eq(buyer.address);
        }
    })

    it("should swap an erc1155 item", async function() {
        const amounts = [ 10, 20, 30 ];
        const ids = [ 1, 2, 3 ];
        const itemPrice = JewelScale.mul(30);
        const offerId = await createOffer({
            itemType: 2,
            addr: MockERC1155.address,
            amounts: amounts,
            ids: ids
        }, itemPrice);

        tx = await FixedPriceMarket.connect(buyer).bid(offerId);
        await tx.wait();

        const sellerBalance = await MockJewel.balanceOf(seller.address);
        const fee = itemPrice.mul(commission).div(10000);
        expect(sellerBalance).to.eq(itemPrice.sub(fee));

        for (let i = 0; i < ids.length; i++) {
            const balance = await MockERC1155.balanceOf(buyer.address, ids[i]);
            expect(balance).to.eq(amounts[i]);
        }
    })

    it("should cancel an offer", async function() {
        const itemAmount = 100;
        const itemPrice = JewelScale.mul(30);
        const offerId = await createOffer({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        }, itemPrice);

        await expect(FixedPriceMarket.connect(buyer).cancel(offerId)).to.be.reverted;
        tx = await FixedPriceMarket.connect(seller).cancel(offerId);
        await tx.wait();
        await expect(FixedPriceMarket.connect(seller).cancel(offerId)).to.be.reverted;
    })

    it("should change item price", async function() {
        const itemAmount = 100;
        const itemPrice = JewelScale.mul(30);
        const offerId = await createOffer({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        }, itemPrice);

        const newItemPrice = JewelScale.mul(50);
        await expect(FixedPriceMarket.connect(buyer).changePrice(offerId, newItemPrice)).to.be.reverted;
        tx = await FixedPriceMarket.connect(seller).changePrice(offerId, newItemPrice);
        await tx.wait();
        const offer = await FixedPriceMarket.offers(offerId);
        expect(offer.price).to.eq(newItemPrice);
    })

   async function createOffer(item, price) {
        let tx;
        switch (item.itemType) {
        case 0:
            tx = await MockERC20.connect(seller).mint(seller.address, item.amounts[0]);
            await tx.wait();
            tx = await MockERC20.connect(seller).approve(FixedPriceMarket.address, item.amounts[0]);
            await tx.wait();
            break;

        case 1:
            tx = await MockERC721.connect(seller).mint(seller.address, 100);
            await tx.wait();
            tx = await MockERC721.connect(seller).setApprovalForAll(FixedPriceMarket.address, true);
            await tx.wait();
            break;

        case 2:
            tx = await MockERC1155.connect(seller).mintBatch(seller.address, [1, 2, 3], [100, 100, 100]);
            await tx.wait();
            tx = await MockERC1155.connect(seller).setApprovalForAll(FixedPriceMarket.address, true);
            await tx.wait();
            break;
        }

        tx = await FixedPriceMarket.connect(seller).create(item, price);
        await tx.wait();
        return await FixedPriceMarket.numOffers();
    }
});
