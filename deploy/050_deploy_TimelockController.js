module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy("TimelockController", {
        from: deployer,
        args: [ 86400, [ deployer ], [ deployer ] ],
        log: true,
    });
}

module.exports.tags = [ "TimelockController" ];
