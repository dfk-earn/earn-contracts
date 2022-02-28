const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require('chai');
const AccountABI = require("../abis/Account.json");

describe('Account', function() {
    let players = [];
    let accounts = [];
    let MockItem;

    beforeEach(async function() {
        await deployments.fixture(["AccountFactory", "mocks" ]);
        MockItem = await ethers.getContract("MockItem");
        const AccountFactory = await ethers.getContract("AccountFactory");
        const unnamed = await getUnnamedAccounts();
        for (const playerAddress of unnamed) {
            const playerSigner = await ethers.getSigner(playerAddress);
            const tx = await AccountFactory.connect(playerSigner).createAccount();
            await tx.wait();
            const account = await AccountFactory.accounts(playerAddress);
            players.push(playerSigner);
            accounts.push(account);
        }
    })

    it("should transfer 200 ether from player1 account to player2 account", async function() {
        const Account = await ethers.getContractAt(AccountABI, accounts[0], players[0]);
        const value = ethers.utils.parseEther("200");
        const tx = await Account.sendValue(accounts[1], value, { value });
        await tx.wait();
        const balance = await ethers.provider.getBalance(accounts[1]);
        expect(balance).to.eq(value);
    })

    it("should mint 200 MI", async function() {
        const Account = await ethers.getContractAt(AccountABI, accounts[0], players[0]);
        const data = MockItem.interface.encodeFunctionData("mint", [ 200 ]);
        const tx = await Account.functionCall(MockItem.address, data);
        await tx.wait();
        const balance = await MockItem.balanceOf(accounts[0]);
        expect(balance).to.eq(200);
    })

    it("should revert when player2 invoke functionCall() with player1's account", async function() {
        const Account = await ethers.getContractAt(AccountABI, accounts[0], players[1]);
        const data = MockItem.interface.encodeFunctionData("mint", [ 200 ]);
        await expect(Account.functionCall(MockItem.address, data)).to.be.reverted;
    })

    it("should update whitelist correctly", async function() {
        const Account = await ethers.getContractAt(AccountABI, accounts[0], players[0]);
        let tx = null;
        let whitelist = null;

        tx = await Account.addToWhitelist([
            players[1].address,
            players[2].address
        ]);
        await tx.wait();
        whitelist = await Account.getWhitelist();
        expect(whitelist.includes(players[1].address)).to.be.true;
        expect(whitelist.includes(players[2].address)).to.be.true;

        tx = await Account.removeFromWhitelist([ players[2].address ]);
        await tx.wait();
        whitelist = await Account.getWhitelist();
        expect(whitelist.includes(players[1].address)).to.be.true;
        expect(whitelist.includes(players[2].address)).to.be.false;

        tx = await Account.updateWhitelist(
            [ players[2].address ],
            [ players[1].address ]
        );
        await tx.wait();
        whitelist = await Account.getWhitelist();
        expect(whitelist.includes(players[1].address)).to.be.false;
        expect(whitelist.includes(players[2].address)).to.be.true;
    })
});
