module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;

    await deploy("MockERC1155", {
        from: deployer,
        args: [ "https://dfkearn.com/mocks/erc1155/{id}.json" ],
        log: true,
    })
}

module.exports.tags = [ "MockERC1155", "Mocks" ];
