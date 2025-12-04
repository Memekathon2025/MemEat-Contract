import "@nomicfoundation/hardhat-toolbox-viem";
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
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"], // Dummy key (Hardhat default #0)
    },
  },
} as any;

export default config;
