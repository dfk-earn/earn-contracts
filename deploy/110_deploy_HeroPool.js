module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    const { deployer } = await getNamedAccounts();
    const AuctionHouse = (await deployments.get("AuctionHouse")).address;

    await deployments.deploy("HeroPool", {
        from: deployer,
        proxy: {
            proxyContract: "ERC1967Proxy",
            proxyArgs: ['{implementation}', '{data}'],
            execute: {
                init: {
                    methodName: "initialize",
                    args: [ AuctionHouse ]
                }
            },
        },
        log: true,
    });
}

module.exports.tags = [ "HeroPool" ];
