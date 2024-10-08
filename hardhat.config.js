require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.9",  // Solidity version for your smart contract
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL,  // Replace with your Polygon RPC URL (Infura, Alchemy, etc.)
      accounts: [`0x${process.env.PRIVATE_KEY}`],  // Replace with your wallet's private key
    },
  },
};
