import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.20",
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};
