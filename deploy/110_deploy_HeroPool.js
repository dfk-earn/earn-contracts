const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const auctionHouseAddress = config[network.name]["AuctionHouse"];
    if (!auctionHouseAddress) {
        auctionHouseAddress = (await deployments.get("AuctionHouse")).address;
    }

    await deployments.deploy("HeroPool", {
        from: deployer,
        proxy: {
            proxyContract: "ERC1967Proxy",
            proxyArgs: ['{implementation}', '{data}'],
            execute: {
                init: {
                    methodName: "initialize",
                    args: [ auctionHouseAddress ]
                }
            },
        },
        log: true,
    });
}

module.exports.tags = [ "HeroPool" ];
