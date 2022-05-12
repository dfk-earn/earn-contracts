require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");

module.exports = {
    networks: {
        hardhat: { accounts: { count: 5 } },
        localhost: {
            url: "http://127.0.0.1:8545",
        },
        harmony: {
            url: process.env.DFKEarn_rpcUrl || "https://api.harmony.one",
            accounts: [ process.env.DFKEarn_privateKey ],
            gasPrice: 35e9
        }
    },
    namedAccounts: {
        deployer: 0,
    },
    solidity: {
        version: "0.8.7",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            evmVersion: "london"
        }
    }
};
