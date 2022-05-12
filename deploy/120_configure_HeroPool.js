const config = require("../config/config.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
    network,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const deployment = await deployments.get("HeroPool");  
    const HeroPool = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
        (await ethers.getSigner(deployer))
    );

    let tx = undefined;

    const upgradeScheduler = process.env.DFKEarn_upgradeScheduler || deployer;
    tx = await HeroPool.setUpgradeScheduler(upgradeScheduler);
    await tx.wait();
    console.log(`HeroPool: set upgradeScheduler: ${upgradeScheduler}`);

    const operator = process.env.DFKEarn_operator || deployer;
    tx = await HeroPool.updateOperator(operator, true);
    await tx.wait();
    console.log(`HeroPool: set operator: ${operator}`);

    const questWeights = config[network.name].questWeights || {};
    for (const [ name, [ address, weight ] ] of Object.entries(questWeights)) {
        tx = await HeroPool.updateQuestWeight(address, weight);
        await tx.wait();
        console.log(`HeroPool: update quest weight: ${name} ${address} ${weight}`);
    }
}

module.exports.tags = [ "configureHeroPool" ];
