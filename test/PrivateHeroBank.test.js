const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");
const AccountAbi = require("../abis/Account.json");

async function incrementBlockTimestamp(sec) {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    await ethers.provider.send("evm_mine", [ block.timestamp + sec ]);
}

describe("PrivateHeroBank", function() {
    let PrivateHeroBank;
    let MockHero;
    let MockJewel;
    let owner;
    let operators;
    let users;
    let accounts;
    let collateralPerOperator;
    let tx;

    beforeEach(async function() {
        await deployments.fixture([ "PrivateHeroBank", "AccountFactory", "Mocks" ]);
        PrivateHeroBank = await ethers.getContract("PrivateHeroBank");
        MockHero = await ethers.getContract("MockHero");
        MockJewel = await ethers.getContract("MockJewel");

        const { deployer } = await getNamedAccounts();
        owner = await ethers.getSigner(deployer);

        const unnamed = await getUnnamedAccounts();
        const operator1 = await ethers.getSigner(unnamed[0]);
        const operator2 = await ethers.getSigner(unnamed[1]);
        operators = [ operator1, operator2 ];
        for (const operator of operators) {
            tx = await PrivateHeroBank.connect(owner).updateOperator(
                operator.address,
                true
            );
            await tx.wait();
            tx = await MockHero.connect(operator).setApprovalForAll(
                PrivateHeroBank.address,
                true
            );
            await tx.wait();
        }

        const result = await PrivateHeroBank.COLLATERAL_PER_OPERATOR();
        collateralPerOperator = ethers.BigNumber.from(result);
        tx = await owner.sendTransaction({
            to: PrivateHeroBank.address,
            value: collateralPerOperator.mul(operators.length)
        })
        await tx.wait();
        
        const user1 = await ethers.getSigner(unnamed[2]);
        const user2 = await ethers.getSigner(unnamed[3]);
        users = [ user1, user2 ];
        const AccountFactory = await ethers.getContract("AccountFactory");
        accounts = [];
        const numHeros = 10;
        for (const user of users) {
            tx = await AccountFactory.connect(user).createAccountWithWhitelist([
                PrivateHeroBank.address
            ]);
            await tx.wait();
            const account = await AccountFactory.accounts(user.address);
            accounts.push(account);
            tx = await MockHero.connect(user).mint(account, numHeros);
            await tx.wait();
            tx = await user.sendTransaction({
                to: account,
                value: ethers.utils.parseEther("200")
            })
            await tx.wait();
        }
    })

    it("should withdraw collateral", async function() {
        const oldBalance = await owner.getBalance();

        const account0Heroes = await getHeroes(accounts[0]);
        tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[0],
            account0Heroes.slice(0, 5)
        );
        await tx.wait();

        tx = await PrivateHeroBank.connect(owner).withdrawalCollateral();
        await tx.wait();
        const newBalance = await owner.getBalance();
        const diff = newBalance.sub(oldBalance);
        const oneEther = ethers.utils.parseEther("1");
        expect(diff).to.be.closeTo(
            collateralPerOperator.mul(operators.length - 1),
            oneEther
        );
    })

    it("should borrow/repay heroes", async function() {
        const account0Heroes = await getHeroes(accounts[0]);
        const account1Heroes = await getHeroes(accounts[1]);
        const numBorrows = 4;

        tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[0],
            account0Heroes.slice(0, numBorrows)
        );
        await tx.wait();
        let operatorHeroBalance = await MockHero.balanceOf(operators[0].address);
        expect(operatorHeroBalance).to.eq(numBorrows);
        let accountHeroBalance = await MockHero.balanceOf(accounts[0]);
        expect(accountHeroBalance).to.eq(account0Heroes.length - numBorrows);

        await expect(PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[0],
            account0Heroes.slice(0, numBorrows)
        )).to.be.reverted;
        await expect(PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[1],
            account1Heroes.slice(0, numBorrows)
        )).to.be.reverted;

        tx = await PrivateHeroBank.connect(operators[0]).repayHeroes();
        await tx.wait();
        operatorHeroBalance = await MockHero.balanceOf(operators[0].address);
        expect(operatorHeroBalance).to.eq(0);
        accountHeroBalance = await MockHero.balanceOf(accounts[0]);
        expect(accountHeroBalance).to.eq(account0Heroes.length);
    })

    it("should pay quest fee", async function() {
        const oldBalance = await owner.getBalance();

        const numBorrows = 10;
        const account0Heroes = await getHeroes(accounts[0]);
        for (let i = 0; i < numBorrows / 2; i++) {
            tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
                accounts[0],
                account0Heroes.slice(0, 2)
            );
            await tx.wait();
            tx = await PrivateHeroBank.connect(operators[0]).repayHeroes();
            await tx.wait();
        }

        const feePerHero = await PrivateHeroBank.feePerHero();
        const totalQuestFee = feePerHero.mul(numBorrows);

        const newBalance = await owner.getBalance();
        const diff = newBalance.sub(oldBalance);
        expect(diff).to.eq(totalQuestFee);
    })

    it("should claim compensation", async function() {
        const heroes = await getHeroes(accounts[0]);
        tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[0],
            heroes.slice(0, 5)
        );
        await tx.wait();
        tx = await PrivateHeroBank.connect(operators[1]).borrowHeroes(
            accounts[0],
            heroes.slice(5, 10)
        );
        await tx.wait();

        let numActiveOperators = await PrivateHeroBank.numActiveOperators();
        expect(numActiveOperators).to.eq(2);

        const Account = new ethers.Contract(accounts[0], AccountAbi, users[0]);
        const data = PrivateHeroBank.interface.encodeFunctionData("claimCompensation");
        await expect(Account.functionCall(PrivateHeroBank.address, data)).to.be.reverted;

        await incrementBlockTimestamp(3 * 24 * 3600 + 1);
        const oldBalance = await ethers.provider.getBalance(accounts[0]);
        tx = await Account.functionCall(PrivateHeroBank.address, data);
        await tx.wait();
        const newBalance = await ethers.provider.getBalance(accounts[0]);
        const diff = newBalance.sub(oldBalance);
        expect(diff).to.eq(collateralPerOperator.mul(2));

        numActiveOperators = await PrivateHeroBank.numActiveOperators();
        expect(numActiveOperators).to.eq(0);
    })

    it("should claim jewel", async function() {
        // borrow and repay 4 heroes from accounts[0]
        const account0Heroes = await getHeroes(accounts[0]);
        tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[0],
            account0Heroes.slice(0, 4)
        );
        await tx.wait();
        tx = await PrivateHeroBank.connect(operators[0]).repayHeroes();
        await tx.wait();

        // borrow and repay 6 heroes from accounts[1]
        const account1Heroes = await getHeroes(accounts[1]);
        tx = await PrivateHeroBank.connect(operators[0]).borrowHeroes(
            accounts[1],
            account1Heroes.slice(0, 6)
        );
        await tx.wait();
        tx = await PrivateHeroBank.connect(operators[0]).repayHeroes();
        await tx.wait();

        const totalScore = await PrivateHeroBank.totalScore();
        expect(totalScore).to.eq(10);
        const account0Score = await PrivateHeroBank.accountScores(accounts[0]);
        expect(account0Score).to.eq(4);
        const account1Score = await PrivateHeroBank.accountScores(accounts[1]);
        expect(account1Score).to.eq(6);

        // mint 100 jewel for PrivateHeroBank
        const jewelScale = ethers.BigNumber.from(10).pow(18);
        tx = await MockJewel.connect(owner).mint(
            PrivateHeroBank.address,
            jewelScale.mul(100)
        );
        await tx.wait();

        // accounts[0] should claim 40 jewel and accounts[1] should claim 60 jewel
        const data = PrivateHeroBank.interface.encodeFunctionData("claimJewel");
        const Account0 = new ethers.Contract(accounts[0], AccountAbi, users[0]);
        tx = await Account0.functionCall(PrivateHeroBank.address, data);
        await tx.wait();
        const account0Balance = await MockJewel.balanceOf(accounts[0]);
        expect(account0Balance).to.eq(jewelScale.mul(40));

        const Account1 = new ethers.Contract(accounts[1], AccountAbi, users[1]);
        tx = await Account1.functionCall(PrivateHeroBank.address, data);
        await tx.wait();
        const account1Balance = await MockJewel.balanceOf(accounts[1]);
        expect(account1Balance).to.eq(jewelScale.mul(60));
    })

    async function getHeroes(account) {
        const heroes = [];
        const numHeroes = await MockHero.balanceOf(account);
        for (let i = 0; i < numHeroes; i++) {
            const heroId = await MockHero.tokenOfOwnerByIndex(account, i);
            heroes.push(heroId);
        }
        return heroes;
    }
});
