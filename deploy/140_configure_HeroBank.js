module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("HeroBank");  
    const HeroBank = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        await ethers.getSigner(deployer)
    );

    const operator = process.env.DFKEarn_operator || deployer;
    const tx = await HeroBank.setOperator(operator);
    await tx.wait();
    console.log(`HeroBank: set operator: ${operator}`);
}

module.exports.tags = [ "configureHeroBank" ];
