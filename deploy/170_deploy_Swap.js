module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const e1 = ethers.utils.parseUnits("1", 'ether')
    await deployments.deploy("ESwap", {
        from: deployer,
        args: [ e1, 0],
        log: true
    });
}

module.exports.tags = [ "ESwap" ];
