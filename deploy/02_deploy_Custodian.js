const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    let { DFKQuest, DFKVender, DFKGold } = config[network.name];
    if (!network.live) {
        DFKQuest = (await deployments.get("MockQuest")).address;
        DFKVender = ethers.constants.AddressZero;
        DFKGold = ethers.constants.AddressZero;
    }

    const { deployer } = await getNamedAccounts();
    await deployments.deploy("Custodian", {
        from: deployer,
        args: [ DFKQuest, DFKVender, DFKGold ],
        log: true,
    })
}
