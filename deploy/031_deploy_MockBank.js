module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    const MockJewelAddress = (await deployments.get("MockJewel")).address;

    await deploy("MockBank", {
        from: deployer,
        args: [ MockJewelAddress ],
        log: true
    })
}

module.exports.tags = [ "MockBank", "Mocks" ];
