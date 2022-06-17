const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const { collateralPerOperatorInEther } = config[network.name]["PrivateHeroBank"];
    const DFKHeroAddress = network.live
        ? config[network.name]["DFKHero"]
        : (await deployments.get("MockHero")).address;
    const DFKJewelAddress = network.live
        ? config[network.name]["DFKJewelToken"]
        : (await deployments.get("MockJewel")).address;

    await deployments.deploy("PrivateHeroBank", {
        from: deployer,
        args: [
            DFKHeroAddress,
            DFKJewelAddress,
            ethers.utils.parseEther(collateralPerOperatorInEther.toString())
        ],
        log: true,
    });
}

module.exports.tags = [ "PrivateHeroBank" ];
