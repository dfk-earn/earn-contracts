const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();

    const HeroBankConfig = config[network.name]["HeroBank"];
    const { collateralPerOperatorInEther } = HeroBankConfig;
    const auctionHouseAddress = network.live
        ? HeroBankConfig["AuctionHouse"]
        : (await deployments.get("AuctionHouse")).address;

    const DFKHeroAddress = network.live
        ? config[network.name]["DFKHero"]
        : (await deployments.get("MockHero")).address;
    const DFKJewelAddress = network.live
        ? config[network.name]["DFKJewelToken"]
        : (await deployments.get("MockJewel")).address;
    const DFKBankAddress = network.live
        ? config[network.name]["DFKBank"]
        : (await deployments.get("MockBank")).address;

    await deployments.deploy("HeroBank", {
        from: deployer,
        args: [
            DFKHeroAddress,
            DFKJewelAddress,
            DFKBankAddress,
            auctionHouseAddress,
            ethers.utils.parseEther(collateralPerOperatorInEther.toString())
        ],
        log: true,
    });
}

module.exports.tags = [ "HeroBank" ];
