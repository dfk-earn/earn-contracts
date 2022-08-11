const {
    getNamedAccounts,
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");

const DAY = 86400;
const JewelScalar = ethers.BigNumber.from(10).pow(18);
const ItemValue = JewelScalar.mul(200);
const DailyRentPrice=JewelScalar.mul(15);
const MaxRentDuration = 3 * DAY;
const MinRentDuration = DAY;

async function incrementBlockTimestamp(sec) {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    await ethers.provider.send("evm_mine", [ block.timestamp + sec ]);
}

describe("LoanMarket", function() {
    let LoanMarket;
    let MockJewel;
    let lender;
    let renter, initialRenterBalance;
    let tx;

    beforeEach(async function() {
        await deployments.fixture([ "LoanMarket", "Mocks" ]);
        LoanMarket = await ethers.getContract("LoanMarket");
        MockJewel = await ethers.getContract("MockJewel");
        MockERC20 = await ethers.getContract("MockERC20");
        MockERC721 = await ethers.getContract("MockHero");
        MockERC1155 = await ethers.getContract("MockERC1155");

        const unnamed = await getUnnamedAccounts();
        lender = await ethers.getSigner(unnamed[0]);
        renter = await ethers.getSigner(unnamed[1]);

        initialRenterBalance = JewelScalar.mul(1000);
        tx = await MockJewel.connect(renter).mint(renter.address, initialRenterBalance);
        await tx.wait();
        tx = await MockJewel.connect(renter).approve(
            LoanMarket.address,
            ethers.constants.MaxUint256
        );
        await tx.wait();
    })

    it("should rent an erc20 item", async function() {
        const itemAmount = 100;
        const id = await create({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        });

        const rentDays = 2;
        tx = await LoanMarket.connect(renter).rent(id, rentDays * DAY);
        await tx.wait();
        
        const currentBalance = await MockJewel.balanceOf(renter.address);
        const payment = ItemValue.add(DailyRentPrice.mul(rentDays));
        expect(currentBalance).to.eq(initialRenterBalance.sub(payment));

        const renterItemAmount = await MockERC20.balanceOf(renter.address);
        expect(renterItemAmount).to.eq(itemAmount);

        await expect(LoanMarket.connect(lender).cancel(id)).to.be.reverted;
    })

    it("should repay an erc721 item", async function() {
        const itemAmount = 100;
        const id = await create({
            itemType: 1,
            addr: MockERC721.address,
            amounts: [],
            ids: [ 1, 2, 3 ]
        });

        await expect(LoanMarket.connect(renter).rent(id, MaxRentDuration + 1)).to.be.reverted;
        await expect(LoanMarket.connect(renter).rent(id, MinRentDuration - 1)).to.be.reverted;

        tx = await LoanMarket.connect(renter).rent(id, MaxRentDuration);
        await tx.wait();

        const rentDays = 2;
        await incrementBlockTimestamp(rentDays * DAY);
        tx = await MockERC721.connect(renter).setApprovalForAll(LoanMarket.address, true);
        await tx.wait();
        tx = await LoanMarket.connect(renter).repay(id);
        await tx.wait();
        
        const currentBalance = await MockJewel.balanceOf(renter.address);
        const cost = DailyRentPrice.mul(rentDays);
        expect(currentBalance).to.be.closeTo(
            initialRenterBalance.sub(cost),
            JewelScalar
        );
    })


    it("should claim collateral", async function() {
        const itemIds = [ 1, 2, 3 ];
        const itemAmounts = [ 10, 20, 30 ];
        const id = await create({
            itemType: 2,
            addr: MockERC1155.address,
            amounts: itemAmounts,
            ids: itemIds
        });

        const rentDuration = 2 * DAY;
        tx = await LoanMarket.connect(renter).rent(id, rentDuration);
        await tx.wait();

        incrementBlockTimestamp(rentDuration + 10);
        await expect(LoanMarket.connect(renter).repay(id)).to.be.reverted;

        tx = await LoanMarket.connect(lender).settle(id);
        await tx.wait();

        const { payment, commission } = await LoanMarket.loans(id);
        const cost = payment.sub(ItemValue);
        const fee = cost.mul(commission).div(10000);
        const { deployer } = await getNamedAccounts();
        const ownerBalance = await MockJewel.balanceOf(deployer);
        expect(ownerBalance).to.eq(fee);
        const lenderBalance = await MockJewel.balanceOf(lender.address);
        expect(lenderBalance).to.eq(payment.sub(fee));
    })

    it("should cancel lending", async function() {
        const itemAmount = 100;
        const id = await create({
            itemType: 0,
            addr: MockERC20.address,
            amounts: [ itemAmount ],
            ids: []
        });

        tx = await LoanMarket.connect(lender).cancel(id);
        await tx.wait();
        const itembalance = await MockERC20.balanceOf(lender.address);
        expect(itembalance).to.eq(itembalance);
    })

   async function create(item) {
        let tx;
        switch (item.itemType) {
        case 0:
            tx = await MockERC20.connect(lender).mint(lender.address, item.amounts[0]);
            await tx.wait();
            tx = await MockERC20.connect(lender).approve(LoanMarket.address, item.amounts[0]);
            await tx.wait();
            break;

        case 1:
            tx = await MockERC721.connect(lender).mint(lender.address, 100);
            await tx.wait();
            tx = await MockERC721.connect(lender).setApprovalForAll(LoanMarket.address, true);
            await tx.wait();
            break;

        case 2:
            tx = await MockERC1155.connect(lender).mintBatch(lender.address, [1, 2, 3], [100, 100, 100]);
            await tx.wait();
            tx = await MockERC1155.connect(lender).setApprovalForAll(LoanMarket.address, true);
            await tx.wait();
            break;
        }

        tx = await LoanMarket.connect(lender).create(
            item,
            MaxRentDuration,
            MinRentDuration,
            ItemValue,
            DailyRentPrice
        );
        await tx.wait();
        return await LoanMarket.numLoans();
    }
});
