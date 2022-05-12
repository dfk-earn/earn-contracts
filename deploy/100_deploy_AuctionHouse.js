const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const DFKJewelToken = network.live
        ? config[network.name]["DFKJewelToken"]
        : (await deployments.get("MockJewel")).address;
    const commission = 800; // 8%
    const tickSize = ethers.BigNumber.from(10).pow(17); // 0.1 jewel

    await deployments.deploy("AuctionHouse", {
        from: deployer,
        args: [ DFKJewelToken, commission, tickSize ],
        log: true
    });
}

module.exports.tags = [ "AuctionHouse" ];
