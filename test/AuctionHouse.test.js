const {
    getUnnamedAccounts,
    deployments,
    ethers,
    getNamedAccounts,
} = require("hardhat");
const { expect } = require("chai");

const JewelScale = ethers.BigNumber.from(10).pow(18);

async function incrementBlockTimestamp(sec) {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    await ethers.provider.send("evm_mine", [ block.timestamp + sec ]);
}

describe("AuctionHouseMarket", function() {
    let AuctionHouse;
    let MockJewel;
    let seller;
    let buyer1;
    let buyer2;
    let initialBalance;
    let commission;
    let tx;

    beforeEach(async function() {
        await deployments.fixture(["AuctionHouse", "Mocks" ]);
        AuctionHouse = await ethers.getContract("AuctionHouse");
        commission = await AuctionHouse.commission();
        MockJewel = await ethers.getContract("MockJewel");
        MockERC20 = await ethers.getContract("MockERC20");
        MockERC721 = await ethers.getContract("MockHero");
        MockERC1155 = await ethers.getContract("MockERC1155");

        const { deployer } = await getNamedAccounts();
        const deployerSigner = await ethers.getSigner(deployer);
        tx = await AuctionHouse.connect(deployerSigner).setMinExpiration(0);
        await tx.wait();

        const unnamed = await getUnnamedAccounts();
        seller = await ethers.getSigner(unnamed[0]);
        buyer1 = await ethers.getSigner(unnamed[1]);
        buyer2 = await ethers.getSigner(unnamed[2]);

        initialBalance = JewelScale.mul(100);
        for (const buyer of [ buyer1, buyer2 ]) {
            tx = await MockJewel.connect(buyer).mint(buyer.address, initialBalance);
            await tx.wait();
            tx = await MockJewel.connect(buyer).approve(AuctionHouse.address, initialBalance);
            await tx.wait();
        }
    })

    it("should swap an erc20 item", async function() {
        const itemAmount = 100;
        const minPrice = JewelScale.mul(30);
        const auctionId = await createAuction({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        }, minPrice);

        let buyer1Price = JewelScale.mul(29);
        await expect(AuctionHouse.connect(buyer1).bid(
            auctionId,
            buyer1Price,
            ethers.constants.AddressZero
        )).to.be.reverted;

        buyer1Price = JewelScale.mul(31);
        tx = await AuctionHouse.connect(buyer1).bid(
            auctionId,
            buyer1Price,
            ethers.constants.AddressZero
        );
        await tx.wait();

        let buyer2Price = JewelScale.mul(31);
        await expect(AuctionHouse.connect(buyer2).bid(
            auctionId,
            buyer2Price,
            ethers.constants.AddressZero
        )).to.be.reverted;

        buyer2Price = JewelScale.mul(32);
        tx = await AuctionHouse.connect(buyer2).bid(
            auctionId,
            buyer2Price,
            ethers.constants.AddressZero
        );
        await tx.wait();

        await incrementBlockTimestamp(5000);
        const isAuctionEnd = await AuctionHouse.isAuctionEnd(auctionId);
        expect(isAuctionEnd).to.be.true;
        
        tx = await AuctionHouse.complete(auctionId);
        await tx.wait();

        const sellerBalance = await MockJewel.balanceOf(seller.address);
        const fee = buyer2Price.mul(commission).div(10000);
        expect(sellerBalance).to.eq(buyer2Price.sub(fee));

        const buyer1Balance = await MockJewel.balanceOf(buyer1.address);
        expect(buyer1Balance).to.eq(initialBalance);

        const buyer2Balance = await MockJewel.balanceOf(buyer2.address);
        expect(buyer2Balance).to.eq(initialBalance.sub(buyer2Price));

        const buyer2ItemBalance = await MockERC20.balanceOf(buyer2.address);
        expect(buyer2ItemBalance).to.eq(itemAmount);
    })

    it("should swap an erc721 item", async function() {
        const ids = [ 1, 2, 3 ];
        const minPrice = JewelScale.mul(30);
        const auctionId = await createAuction({
            itemType: 1,
            addr: MockERC721.address,
            amounts: [ ],
            ids: ids
        }, minPrice);

        tx = await AuctionHouse.connect(buyer1).bid(
            auctionId,
            minPrice,
            ethers.constants.AddressZero
        );
        await tx.wait();

        await incrementBlockTimestamp(5000);
        tx = await AuctionHouse.complete(auctionId);
        await tx.wait();

        for (let i = 0; i < ids.length; i++) {
            const owner = await MockERC721.ownerOf(ids[i]);
            expect(owner).to.eq(buyer1.address);
        }
    })

    it("should swap an erc1155 item", async function() {
        const amounts = [ 10, 20, 30 ];
        const ids = [ 1, 2, 3 ];
        const minPrice = JewelScale.mul(30);
        const auctionId = await createAuction({
            itemType: 2,
            addr: MockERC1155.address,
            amounts: amounts,
            ids: ids
        }, minPrice);

        tx = await AuctionHouse.connect(buyer1).bid(
            auctionId,
            minPrice,
            ethers.constants.AddressZero
        );
        await tx.wait();

        await incrementBlockTimestamp(5000);
        tx = await AuctionHouse.complete(auctionId);
        await tx.wait();

        for (let i = 0; i < ids.length; i++) {
            const balance = await MockERC1155.balanceOf(buyer1.address, ids[i]);
            expect(balance).to.eq(amounts[i]);
        }
    })

    it("should cancel an auction", async function() {
        const auctionId = await createAuction({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ 100 ],
            ids: []
        }, JewelScale.mul(30));

        await expect(AuctionHouse.connect(buyer1).cancel(auctionId)).to.be.reverted;
        tx = await AuctionHouse.connect(seller).cancel(auctionId);
        await tx.wait();
        await expect(AuctionHouse.connect(seller).cancel(auctionId)).to.be.reverted;
    })

    it("should change minPrice", async function() {
        const minPrice = JewelScale.mul(30);
        const auctionId = await createAuction({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ 100 ],
            ids: []
        }, minPrice);

        const newMinPrice = JewelScale.mul(50);
        await expect(AuctionHouse.connect(buyer1).changeMinPrice(auctionId, newMinPrice)).to.be.reverted;
        tx = await AuctionHouse.connect(seller).changeMinPrice(auctionId, newMinPrice);
        await tx.wait();
        const auction = await AuctionHouse.auctions(auctionId);
        expect(auction.minPrice).to.eq(newMinPrice);
    })

   async function createAuction(item, price) {
        let tx;
        switch (item.itemType) {
        case 0:
            tx = await MockERC20.connect(seller).mint(seller.address, item.amounts[0]);
            await tx.wait();
            tx = await MockERC20.connect(seller).approve(AuctionHouse.address, item.amounts[0]);
            await tx.wait();
            break;

        case 1:
            tx = await MockERC721.connect(seller).mint(seller.address, 100);
            await tx.wait();
            tx = await MockERC721.connect(seller).setApprovalForAll(AuctionHouse.address, true);
            await tx.wait();
            break;

        case 2:
            tx = await MockERC1155.connect(seller).mintBatch(seller.address, [1, 2, 3], [100, 100, 100]);
            await tx.wait();
            tx = await MockERC1155.connect(seller).setApprovalForAll(AuctionHouse.address, true);
            await tx.wait();
            break;
        }

        tx = await AuctionHouse.connect(seller).create(item, price, 3600);
        await tx.wait();
        return await AuctionHouse.numAuctions();
    }
});
