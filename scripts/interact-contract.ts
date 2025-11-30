import { network } from "hardhat";
import { createPublicClient, http, createWalletClient, custom } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import dotenv from "dotenv";

dotenv.config();

// 배포된 컨트랙트 주소 (Insectarium Testnet)
const CONTRACT_ADDRESSES = {
  mockPriceFetcher: "0x9368cA91aA343561beA8d88BC7336ca2E95c6e69",
  oracleAdapter: "0x50437b0960d719313Eeea64f370219103D7a6070",
  wormGame: "0x81CD91E8255bb8926746Aa630185F80F2f8A3a84",
};

// Insectarium Testnet RPC URL
const RPC_URL = "https://rpc.insectarium.memecore.net";

async function main() {
  console.log("=== 배포된 컨트랙트 확인 ===\n");
  console.log("네트워크:", network.name);
  console.log("RPC URL:", RPC_URL);
  console.log("");

  // 직접 PublicClient 생성 (체인 ID 인식 문제 해결)
  const publicClient = createPublicClient({
    transport: http(RPC_URL),
  });

  // network.connect()는 컨트랙트 읽기에만 사용 (getPublicClient 호출 안 함)
  const { viem } = await network.connect();

  // WormGame 컨트랙트 확인
  if (CONTRACT_ADDRESSES.wormGame !== "0x...") {
    try {
      const wormGame = await viem.getContractAt(
        "WormGame",
        CONTRACT_ADDRESSES.wormGame as `0x${string}`
      );

      console.log("📋 WormGame 컨트랙트 정보:");
      console.log("  주소:", CONTRACT_ADDRESSES.wormGame);
      
      // 컨트랙트 상태 읽기
      const oracleAdapter = await wormGame.read.oracleAdapter();
      const serverSigner = await wormGame.read.serverSigner();
      const minExitValue = await wormGame.read.minExitValue();
      const owner = await wormGame.read.owner();

      console.log("  OracleAdapter:", oracleAdapter);
      console.log("  ServerSigner:", serverSigner);
      console.log("  MinExitValue:", minExitValue.toString());
      console.log("  Owner:", owner);
      console.log("");

      // 컨트랙트 코드 확인
      try {
        const code = await publicClient.getBytecode({
          address: CONTRACT_ADDRESSES.wormGame as `0x${string}`,
        });
        console.log("  컨트랙트 코드 배포 여부:", code && code !== "0x" ? "✅ 배포됨" : "❌ 배포 안됨");
        console.log("");
      } catch (error) {
        console.log("  컨트랙트 코드 확인 실패 (RPC 연결 문제일 수 있음)");
        console.log("");
      }

    } catch (error) {
      console.error("WormGame 컨트랙트 확인 중 오류:", error);
    }
  } else {
    console.log("⚠️  CONTRACT_ADDRESSES.wormGame을 배포된 주소로 변경하세요");
    console.log("");
  }

  // OracleAdapter 컨트랙트 확인
  if (CONTRACT_ADDRESSES.oracleAdapter !== "0x...") {
    try {
      const oracleAdapter = await viem.getContractAt(
        "UserOnChainPriceOracleAdapter",
        CONTRACT_ADDRESSES.oracleAdapter as `0x${string}`
      );

      console.log("📋 OracleAdapter 컨트랙트 정보:");
      console.log("  주소:", CONTRACT_ADDRESSES.oracleAdapter);
      
      const priceFetcher = await oracleAdapter.read.priceFetcher();
      console.log("  PriceFetcher:", priceFetcher);
      console.log("");

    } catch (error) {
      console.error("OracleAdapter 컨트랙트 확인 중 오류:", error);
    }
  }

  // MockPriceFetcher 컨트랙트 확인
  if (CONTRACT_ADDRESSES.mockPriceFetcher !== "0x...") {
    try {
      const mockPriceFetcher = await viem.getContractAt(
        "MockPriceFetcher",
        CONTRACT_ADDRESSES.mockPriceFetcher as `0x${string}`
      );

      console.log("📋 MockPriceFetcher 컨트랙트 정보:");
      console.log("  주소:", CONTRACT_ADDRESSES.mockPriceFetcher);
      console.log("");

    } catch (error) {
      console.error("MockPriceFetcher 컨트랙트 확인 중 오류:", error);
    }
  }

  console.log("=== 확인 완료 ===");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

