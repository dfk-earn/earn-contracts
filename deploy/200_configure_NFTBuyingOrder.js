const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("NFTBuyingOrder");  
    const NFTBuyingOrder = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        await ethers.getSigner(deployer)
    );

    const DFKJewelToken = network.live
        ? config[network.name]["DFKJewelToken"]
        : (await deployments.get("MockJewel")).address;
    const tx = await NFTBuyingOrder.updatePaymentToken(DFKJewelToken, true);
    await tx.wait();
    console.log(`NFTBuyingOrder: add paymentToken: ${DFKJewelToken}`);
}

module.exports.tags = [ "configureNFTBuyingOrder" ];
