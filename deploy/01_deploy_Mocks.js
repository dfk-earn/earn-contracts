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

    await deploy("MockReward", {
        from: deployer,
        log: true,
    })
    
    await deploy("MockQuest", {
        from: deployer,
        log: true,
    })
}
