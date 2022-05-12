module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    
    await deploy("MockQuest", {
        from: deployer,
        log: true,
    })
}

module.exports.tags = [ "MockQuest", "Mocks" ];
