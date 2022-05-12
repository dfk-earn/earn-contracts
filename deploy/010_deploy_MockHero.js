module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;

    await deploy("MockHero", {
        from: deployer,
        log: true,
    })
}

module.exports.tags = [ "MockHero", "Mocks" ];
