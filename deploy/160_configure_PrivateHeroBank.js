module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("PrivateHeroBank");  
    const PrivateHeroBank = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        await ethers.getSigner(deployer)
    );

    const operator = process.env.DFKEarn_operator || deployer;
    const tx = await PrivateHeroBank.updateOperator(operator, true);
    await tx.wait();
    console.log(`PrivateHeroBank: set operator: ${operator}`);
}

module.exports.tags = [ "configurePrivateHeroBank" ];
