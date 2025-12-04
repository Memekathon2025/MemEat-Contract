import "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";
import dotenv from "dotenv";

// .env 파일 로드
// .env 파일 로드 (순서: .env.local -> .env)
dotenv.config({ path: ".env.local" });
dotenv.config();

const config = {
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    insectarium: {
      type: "http",
      chainType: "l1",
      url: "https://rpc.insectarium.memecore.net",
      chainId: 43522,
      accounts: [
        process.env.INSECTARIUM_PRIVATE_KEY ||
          configVariable("INSECTARIUM_PRIVATE_KEY"),
      ],
    },
    formicarium: {
      type: "http",
      chainType: "l1",
      url: "https://rpc.formicarium.memecore.net	",
      chainId: 43521,
      accounts: [
        process.env.INSECTARIUM_PRIVATE_KEY ||
          configVariable("INSECTARIUM_PRIVATE_KEY"),
      ],
    },
    memecore: {
      type: "http",
      chainType: "l1",
      url: "https://rpc.memecore.net",
      chainId: 4352,
      accounts: [
        process.env.INSECTARIUM_PRIVATE_KEY ||
          configVariable("INSECTARIUM_PRIVATE_KEY"),
      ],
    },
  },
} as any;

export default config;
