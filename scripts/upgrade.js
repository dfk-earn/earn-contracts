require("dotenv").config();
const { ethers } = require("ethers");
const { program } = require("commander");
const TimelockControllerAbi = require("../abis/TimelockController.json");

const UUPSUpgradeableInterface = new ethers.utils.Interface([
    "function upgradeTo(address newImplementation)",
    "function upgradeToAndCall(address newImplementation, bytes data) payable"
]);

async function schedule(
    timelockController,
    proxy,
    newImplementation,
    delay
) {
    const TimelockController = getTimelockController(timelockController);
    const tx = await TimelockController.schedule(
        proxy,
        0,                              // value
        UUPSUpgradeableInterface.encodeFunctionData(
            "upgradeTo",
            [ newImplementation ]
        ),
        ethers.utils.zeroPad([], 32),   // predecessor 
        ethers.utils.zeroPad([], 32),   // salt
        delay
    );
    const receipt = await tx.wait();
    console.log(`upgrade scheduled, txhash: ${receipt.transactionHash}`);
}

async function execute({
    timelockController,
    proxy,
    newImplementation,
}) {
    const TimelockController = getTimelockController(timelockController);
    const tx = await TimelockController.execute(
        proxy,
        0,                              // value
        UUPSUpgradeableInterface.encodeFunctionData(
            "upgradeTo",
            [ newImplementation ]
        ),
        ethers.utils.zeroPad([], 32),   // predecessor
        ethers.utils.zeroPad([], 32),   // salt
    );
    const receipt = await tx.wait();
    console.log(`upgrade executed, txhash: ${receipt.transactionHash}`);
}

function getTimelockController(address) {
    const provider = ethers.getDefaultProvider(process.env.DFKEarn_rpcUrl);
    const signer = new ethers.Wallet(process.env.DFKEarn_privateKey, provider);
    return new ethers.Contract(
        address,
        TimelockControllerAbi,
        signer
    );
}

async function main() {
    program
        .command("schedule")
        .argument("<timelockController>")
        .argument("<proxy>")
        .argument("<newImplementation>")
        .argument("[delay]", "", parseFloat, 172800)
        .action(schedule);

    program
        .command("execute")
        .argument("<timelockController>")
        .argument("<proxy>")
        .argument("<newImplementation>")
        .action(execute);

    await program.parseAsync();
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
