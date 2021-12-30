const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("Custodian");
    const Custodian = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        await ethers.getSigner(deployer)
    );

    const txResponse = await Custodian.setOperator(deployer);
    txResponse.wait()
    console.log(`set operator to: ${deployer}`);

    const questTypes = config[network.name].questTypes;
    for (const [name, address] of Object.entries(questTypes)) {
        const txResponse = await Custodian.addQuestType(address);
        await txResponse.wait()
        console.log(`add ${name} quest: ${address}`);
    }
}
