const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require('chai');
const AccountABI = require("../abis/Account.json");

describe('AccountFactory', function() {
    let player1;
    let player2;
    let AccountFactory;

    beforeEach(async function() {
        await deployments.fixture("AccountFactory");
        const unnamed = await getUnnamedAccounts();
        player1 = await ethers.getSigner(unnamed[0]);
        player2 = await ethers.getSigner(unnamed[1]);
        AccountFactory = await ethers.getContract("AccountFactory");
    })

    it("should create two accounts", async function() {
        for (const player of [ player1, player2 ]) {
            const tx = await AccountFactory.connect(player).createAccount();
            await tx.wait();
            const accountAddress = await AccountFactory.accounts(player.address);
            const Account = await ethers.getContractAt(AccountABI, accountAddress);
            const owner = await Account.owner();
            console.log(`owner: ${owner}`);
            expect(owner).to.eq(player.address);
        }
        const total = await AccountFactory.total();
        expect(total).to.equal(2);
    })

    it("should create an account with 50 ether balance", async function() {
        const value = ethers.utils.parseEther("50");
        const tx = await AccountFactory.connect(player1).createAccount({ value });
        await tx.wait();
        const accountAddress = await AccountFactory.accounts(player1.address);
        const balance = await ethers.provider.getBalance(accountAddress);
        expect(balance).to.equal(value);
    })

    it("should create an account with specified whitelist", async function() {
        const mockAddress = "0x29B5738f5b5d6a4b53ab3f0a256773fc7DB7069E";
        const tx = await AccountFactory.connect(player1).createAccountWithWhitelist([ mockAddress ]);
        await tx.wait();
        const accountAddress = await AccountFactory.accounts(player1.address);
        const Account = await ethers.getContractAt(AccountABI, accountAddress);
        const whitelist = await Account.getWhitelist();
        expect(whitelist).to.have.members([ mockAddress ]);
    })
});
