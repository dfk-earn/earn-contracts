module.exports = async function({
    getNamedAccounts,
    deployments,
    network
}) {
    if (network.live) {
        return
    }

    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;

    await deploy("MockHero", {
        from: deployer,
        log: true,
    })

    await deploy("MockItem", {
        from: deployer,
        log: true,
    })

    await deploy("MockJewel", {
        from: deployer,
        log: true,
    })
    
    await deploy("MockQuest", {
        from: deployer,
        log: true,
    })
}

module.exports.tags = [ "mocks" ];
