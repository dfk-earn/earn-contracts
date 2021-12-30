require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");

module.exports = {
    defaultNetwork: "localhost",
    networks: {
        hardhat: {},
        localhost: {
            url: "http://127.0.0.1:8545",
        },
        harmony: {
            url: process.env.DFKTools_RpcUrl || "https://api.harmony.one",
            accounts: [ process.env.DFKTools_PrivateKey ]
        }
    },
    namedAccounts: {
        deployer: 0,
    },
    solidity: "0.8.4",
};
