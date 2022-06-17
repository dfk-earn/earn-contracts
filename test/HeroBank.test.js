const {
    getUnnamedAccounts,
    deployments,
    ethers
} = require("hardhat");
const { expect } = require("chai");

describe("HeroBank", function() {
    let HeroBank;
    let MockHero;
    let MockJewel;
    let owner;
    let operators;
    let users;
    let collateralPerOperator;
    let tx;

    beforeEach(async function() {
        await deployments.fixture([ "AuctionHouse", "HeroBank", "Mocks" ]);
        HeroBank = await ethers.getContract("HeroBank");
        MockHero = await ethers.getContract("MockHero");
        MockJewel = await ethers.getContract("MockJewel");

        const { deployer } = await getNamedAccounts();
        owner = await ethers.getSigner(deployer);

        const unnamed = await getUnnamedAccounts();
        const operator1 = await ethers.getSigner(unnamed[0]);
        const operator2 = await ethers.getSigner(unnamed[1]);
        operators = [ operator1, operator2 ];
        for (const operator of operators) {
            tx = await HeroBank.connect(owner).updateOperator(
                operator.address,
                true
            );
            await tx.wait();
            tx = await MockHero.connect(operator).setApprovalForAll(
                HeroBank.address,
                true
            );
            await tx.wait();
        }

        const result = await HeroBank.COLLATERAL_PER_OPERATOR();
        collateralPerOperator = ethers.BigNumber.from(result);
        
        tx = await owner.sendTransaction({
            to: HeroBank.address,
            value: collateralPerOperator.mul(operators.length)
        })
        await tx.wait();

        const user1 = await ethers.getSigner(unnamed[2]);
        const user2 = await ethers.getSigner(unnamed[3]);
        users = [ user1, user2 ];

        const numHeros = 10;
        for (const user of [ user1, user2 ]) {
            tx = await MockHero.connect(user).mint(user.address, numHeros);
            await tx.wait();
            for (let i = 0; i < numHeros; i++) {
                const heroId = await MockHero.tokenOfOwnerByIndex(user.address, 0);
                tx = await MockHero.connect(user)["safeTransferFrom(address,address,uint256)"](
                    user.address,
                    HeroBank.address,
                    heroId
                );
                await tx.wait();
            }
        }
    })

    it("should withdraw collateral", async function() {
        const oldBalance = await owner.getBalance();

        const user0Heroes = await getHeroes(users[0].address);
        tx = await HeroBank.connect(operators[0]).borrowHeroes(user0Heroes.slice(0, 5));
        await tx.wait();

        const numActiveOperators = await HeroBank.numActiveOperators();
        expect(numActiveOperators).to.eq(1);

        tx = await HeroBank.connect(owner).withdrawalCollateral();
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
        let heroes = [ 1, 2, 3, 4, 5, 6, 7];
        await expect(HeroBank.connect(operators[0]).borrowHeroes(heroes)).to.be.reverted;

        heroes = [ 8, 9, 10, 11 ];
        tx = await HeroBank.connect(operators[0]).borrowHeroes(heroes);
        await tx.wait();
        let numHeroes = await MockHero.balanceOf(operators[0].address);
        expect(numHeroes).to.eq(heroes.length);

        heroes = [ 12, 13 ];
        await expect(HeroBank.connect(operators[0]).borrowHeroes(heroes)).to.be.reverted;

        tx = await HeroBank.connect(operators[0]).repayHeroes();
        await tx.wait()
        numHeroes = await MockHero.balanceOf(operators[0].address);
        expect(numHeroes).to.eq(0);
    })

    it("should withdraw heroes", async function() {
        let heroes = [ 1, 2, 3 ];

        tx = await HeroBank.connect(operators[0]).borrowHeroes(heroes);
        await tx.wait();
        await expect(HeroBank.connect(users[0]).withdrawalHeroes(heroes)).to.be.reverted;
        
        tx = await HeroBank.connect(operators[0]).repayHeroes();
        await tx.wait();
        await expect(HeroBank.connect(users[1]).withdrawalHeroes(heroes)).to.be.reverted;
        tx = await HeroBank.connect(users[0]).withdrawalHeroes(heroes);
        await tx.wait();
        for (const heroId of heroes) {
            const owner = await MockHero.ownerOf(heroId);
            expect(owner).to.eq(users[0].address);
        }
    })

    // it("should claim money", async function() {
    //     // borrow and repay two heroes from user1
    //     tx = await HeroBank.connect(operator).borrowHeroes([ 1, 2 ]);
    //     await tx.wait();
    //     tx = await HeroBank.connect(operator).repayHeroes();
    //     await tx.wait()

    //     // borrow and repay four heroes from user2
    //     tx = await HeroBank.connect(operator).borrowHeroes([ 11, 12, 13, 14 ]);
    //     await tx.wait();
    //     tx = await HeroBank.connect(operator).repayHeroes();
    //     await tx.wait()

    //     // user1 share should be 2/6, user2 share should be 4/6
    //     const jewelScale = ethers.BigNumber.from(10).pow(18);
    //     tx = await MockJewel.connect(owner).mint(
    //         HeroBank.address,
    //         jewelScale.mul(6)
    //     );
    //     await tx.wait();

    //     tx = await HeroBank.connect(user1).claim();
    //     await tx.wait();
    //     const user1JewelBalance = await MockJewel.balanceOf(user1.address);
    //     expect(user1JewelBalance).to.eq(jewelScale.mul(2));

    //     tx = await HeroBank.connect(user2).claim();
    //     await tx.wait();
    //     const user2JewelBalance = await MockJewel.balanceOf(user2.address);
    //     expect(user2JewelBalance).to.eq(jewelScale.mul(4));
    // })

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
