module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy("AccountFactory", {
        from: deployer,
        log: true
    })
}

module.exports.tags = [ "AccountFactory" ];
