module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("AutoQuest");  
    const DFKEarnQuest = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        await ethers.getSigner(deployer)
    );

    const operator = process.env.DFKEarn_operator || deployer;
    const tx = await DFKEarnQuest.updateOperator(operator, true);
    await tx.wait();
    console.log(`AutoQuest: add operator: ${operator}`);
}

module.exports.tags = [ "configureAutoQuest" ];
