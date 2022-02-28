const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const factoryAddress = (await deployments.get("AccountFactory")).address;
    let jewelAddress = undefined;
    if (network.live) {
        jewelAddress = config[network.name]["JEWEL"];
    } else {
        jewelAddress = (await deployments.get("MockJewel")).address;
    }

    await deployments.deploy("DFKEarnMarket", {
        from: deployer,
        args: [ factoryAddress, jewelAddress ],
        log: true
    })
}

module.exports.tags = [ "DFKEarnMarket", "DFKEarn" ];
