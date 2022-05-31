const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const { maxHeroCount, minCollateralInEther } = config[network.name]["HeroBank"];
    let auctionHouseAddress = config[network.name]["AuctionHouse"];
    if (!auctionHouseAddress) {
        auctionHouseAddress = (await deployments.get("AuctionHouse")).address;
    }
    const DFKHeroAddress = network.live
        ? config[network.name]["DFKHero"]
        : (await deployments.get("MockHero")).address;


    await deployments.deploy("HeroBank", {
        from: deployer,
        args: [
            maxHeroCount,
            ethers.utils.parseEther(minCollateralInEther.toString()),
            auctionHouseAddress,
            DFKHeroAddress
        ],
        log: true,
    });
}

module.exports.tags = [ "HeroBank" ];
