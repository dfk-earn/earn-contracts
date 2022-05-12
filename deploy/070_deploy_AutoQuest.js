const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const factoryAddress = config[network.name]["AccountFactory"];
    if (!factoryAddress) {
        factoryAddress = (await deployments.get("AccountFactory")).address;
    }

    await deployments.deploy("AutoQuest", {
        from: deployer,
        args: [ factoryAddress ],
        log: true
    })
}

module.exports.tags = [ "AutoQuest" ];
