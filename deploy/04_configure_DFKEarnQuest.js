const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const DFKEarnQuestDeployment = await deployments.get("DFKEarnQuest");  
    const DFKEarnQuest = await ethers.getContractAt(
        DFKEarnQuestDeployment.abi,
        DFKEarnQuestDeployment.address,
        await ethers.getSigner(deployer)
    );

    const operator = process.env.DFKEarn_operator || deployer;
    const txResponse = await DFKEarnQuest.addOperator(operator);
    txResponse.wait()
    console.log(`add operator: ${operator}`);

    const questTypes = config[network.name].questTypes || {};
    for (const [name, address] of Object.entries(questTypes)) {
        const txResponse = await DFKEarnQuest.addQuestType(address);
        await txResponse.wait()
        console.log(`add ${name} quest: ${address}`);
    }
}

module.exports.tags = [ "DFKEarnQuest", "DFKEarn" ];
