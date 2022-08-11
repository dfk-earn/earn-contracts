const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments
}) {
    const { deployer } = await getNamedAccounts();
    await deployments.deploy("NFTBuyingOrder", {
        from: deployer,
        args: [ 250 ],
        log: true
    })
}

module.exports.tags = [ "NFTBuyingOrder" ];
