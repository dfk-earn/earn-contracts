const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const DFKJewelToken = network.live
        ? config[network.name]["DFKJewelToken"]
        : (await deployments.get("MockJewel")).address;

    await deployments.deploy("FixedPriceMarket", {
        from: deployer,
        args: [ DFKJewelToken, 250 ],
        log: true
    })
}

module.exports.tags = [ "FixedPriceMarket" ];
