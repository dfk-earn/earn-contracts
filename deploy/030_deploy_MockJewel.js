module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;

    await deploy("MockJewel", {
        from: deployer,
        log: true,
    })
}

module.exports.tags = [ "MockJewel", "Mocks" ];
