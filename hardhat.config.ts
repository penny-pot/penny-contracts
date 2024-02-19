import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200,
      },
    },
  },
  defaultNetwork: "fuji",

  networks: {
    fuji: {
      url: `https://api.avax-test.network/ext/C/rpc`,
      accounts: [
        "",
      ],
    },
  },
};

export default config;
