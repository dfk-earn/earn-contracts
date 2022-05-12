const fs = require("fs");

network = process.argv[2];
contract = process.argv[3];

const inFile = `deployments/${network}/${contract}.json`
const data = fs.readFileSync(inFile, "utf-8");
const abi = JSON.parse(data).abi;

const { ethers } = require("ethers");
const iface = new ethers.utils.Interface(abi);
const humanReadableAbi = iface.format(ethers.utils.FormatTypes.full);
const outFile = `abis/${contract}.json`;
fs.writeFileSync(outFile, JSON.stringify(humanReadableAbi, undefined, 2))
