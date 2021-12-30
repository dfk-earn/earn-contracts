const fs = require("fs");
const data = fs.readFileSync(0, "utf-8");
const jsonAbi = JSON.parse(data);

const { ethers } = require("ethers");
const iface = new ethers.utils.Interface(jsonAbi);
const humanReadableAbi = iface.format(ethers.utils.FormatTypes.full);
console.log(humanReadableAbi);
