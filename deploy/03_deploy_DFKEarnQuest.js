const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const factoryAddress = (await deployments.get("AccountFactory")).address;
    let [ questAddress, jewelAddress ] = [];
    if (network.live) {
        questAddress = config[network.name]["DFKQuest"];
        jewelAddress = config[network.name]["JEWEL"];
    } else {
        questAddress = (await deployments.get("MockQuest")).address;
        jewelAddress = (await deployments.get("MockJewel")).address;
    }

    await deployments.deploy("DFKEarnQuest", {
        from: deployer,
        args: [ factoryAddress, questAddress, jewelAddress ],
        log: true
    })
}

module.exports.tags = [ "DFKEarnQuest", "DFKEarn" ];
