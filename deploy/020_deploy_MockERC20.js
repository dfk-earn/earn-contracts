module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;

    await deploy("MockERC20", {
        from: deployer,
        log: true,
    })
}

module.exports.tags = [ "MockERC20", "Mocks" ];
