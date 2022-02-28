const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require('chai');
const AccountABI = require("../abis/Account.json");

describe('DFKEarnQuest', function() {
    let player;
    let account;
    let DFKEarnQuest;
    let MockItem;
    let MockHero;

    beforeEach(async function() {
        await deployments.fixture(["DFKEarnQuest", "AccountFactory", "mocks" ]);
        const unnamed = await getUnnamedAccounts();
        player = await ethers.getSigner(unnamed[0]);
        DFKEarnQuest = await ethers.getContract("DFKEarnQuest", player);
        MockItem = await ethers.getContract("MockItem", player);
        MockHero = await ethers.getContract("MockHero", player);
        const AccountFactory = await ethers.getContract("AccountFactory", player);
        let tx = await AccountFactory.createAccountWithWhitelist([ DFKEarnQuest.address ]);
        await tx.wait();
        const accountAddress = await AccountFactory.accounts(player.address);
        account = await ethers.getContractAt(AccountABI, accountAddress, player);
    })

    it("should withdraw all MI tokens", async function() {
        // mint 10 MI for player
        const amount = ethers.utils.parseEther("10");
        let tx = await MockItem.mint(amount);
        await tx.wait()
        // transfer 10 MI to account
        tx = await MockItem.transfer(account.address, amount);
        await tx.wait()
        const accountBalance = await MockItem.balanceOf(account.address);
        expect(accountBalance).to.eq(amount);
        // transfer back 10 MI
        tx = await DFKEarnQuest.batchWithdrawalERC20Tokens(
            [ MockItem.address ],
            [ accountBalance ]
        );
        await tx.wait()
        const playerBalance = await MockItem.balanceOf(player.address);
        expect(playerBalance).to.eq(amount);
    })

    it("should withdraw all heros", async function() {
        // mint 3 heros for player
        const heroes = [];
        for (let i = 0; i < 3; i++) {
            let tx = await MockHero.mint();
            await tx.wait()
            const heroId = await MockHero.tokenOfOwnerByIndex(player.address, i);
            heroes.push(heroId.toNumber());
        }
        // transfer 3 heroes to account
        for (const heroId of heroes) {
            tx = await MockHero["safeTransferFrom(address,address,uint256)"](
                player.address,
                account.address,
                heroId
            );
            await tx.wait()
        }
        // transfer back all heroes
        tx = await DFKEarnQuest.batchWithdrawalERC721Tokens(
            MockHero.address,
            heroes
        );
        await tx.wait();
        const count = await MockHero.balanceOf(player.address);
        expect(count).to.eq(3);
        for (let i = 0; i < count; i++) {
            const heroId = await MockHero.tokenOfOwnerByIndex(player.address, i);
            expect(heroes.includes(heroId.toNumber())).to.be.true;
        }
    })
});
