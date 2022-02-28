const {
    getNamedAccounts,
    ethers
} = require("hardhat");
const ERC721ABI = require("../abis/ERC721.json");

const DFKHeroAddress = "0x5F753dcDf9b1AD9AabC1346614D1f4746fd6Ce5C";
const QuestTypes = {
    "gardening": "0xe4154B6E5D240507F9699C730a496790A722DF19",
    "fishing": "0xE259e8386d38467f0E7fFEdB69c3c9C935dfaeFc",
    "foraging": "0x3132c76acF2217646fB8391918D28a16bD8A8Ef4",
    "mining": "0x569E6a4c2e3aF31B337Be00657B4C040C828Dd73"
}

const heroId = 22724;

async function main() {
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.getSigner(deployer);
    const AccountFactory = await ethers.getContract("AccountFactory", signer);
    const DFKEarn = await ethers.getContract("DFKEarn", signer);

    // step1: create account if necessary
    const hasAccount = await AccountFactory.hasAccount(signer.address);
    if (!hasAccount) {
        const tx = await AccountFactory.createAccountWithWhitelist(
            [ DFKEarn.address ],
            { value: ethers.utils.parseEther("1") }
        );
        await tx.wait()
    }

    const account = await AccountFactory.accounts(signer.address);
    console.log(`account: ${account}`);

    // step2: transfer hero to account
    // const DFKHero = await ethers.getContractAt(
    //     ERC721ABI,
    //     DFKHeroAddress,
    //     signer
    // );
    // const tx = await DFKHero["safeTransferFrom(address,address,uint256)"](
    //     signer.address,
    //     account,
    //     heroId
    // );
    // await tx.wait();

    // step3: start gardening quest
    // const tx = await DFKEarn.startQuestWithData(
    //     account,
    //     [ heroId ],
    //     QuestTypes["gardening"],
    //     1,
    //     [
    //         0, 0, 0, 0, 0, 0, "", "", 
    //         ethers.constants.AddressZero,
    //         ethers.constants.AddressZero,
    //         ethers.constants.AddressZero,
    //         ethers.constants.AddressZero,
    //     ]
    // );
    // await tx.wait();

    // step4: cancel quest
    // const tx = await DFKEarn.cancelQuest(
    //     account,
    //     heroId
    // );
    // await tx.wait();

    // step5: withdrawl hero
    // const tx = await DFKEarn.batchWithdrawalERC721Tokens(
    //     DFKHeroAddress,
    //     [ heroId ],
    // );
    // await tx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.log(e);
        process.exit(1);
    });
