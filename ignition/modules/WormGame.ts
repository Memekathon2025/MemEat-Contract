import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * 테스트넷용 배포 모듈 (MockPriceFetcher 사용)
 *
 * 배포 방법:
 * npx hardhat ignition deploy ignition/modules/WormGame.ts --network insectarium --parameters parameters.json
 */
const WormGameModule = buildModule("WormGameModule", (m) => {
  // ServerSigner 주소는 환경 변수(.env) 또는 배포 시 파라미터로 전달받습니다.
  // 우선순위: 파라미터 > 환경 변수 > 기본값
  const serverSignerAddress = m.getParameter<string>(
    "serverSigner",
    process.env.SERVER_SIGNER_ADDRESS || "0x0000000000000000000000000000000000000000"
  );

  // 1. MockPriceFetcher 배포 (의존성 없음)
  const mockPriceFetcher = m.contract("MockPriceFetcher");

  // 2. UserOnChainPriceOracleAdapter 배포 (MockPriceFetcher 주소 필요)
  const oracleAdapter = m.contract("UserOnChainPriceOracleAdapter", [
    mockPriceFetcher,
  ]);

  // 3. WormGame 배포 (OracleAdapter 주소와 ServerSigner 주소 필요)
  const wormGame = m.contract("WormGame", [
    oracleAdapter,
    serverSignerAddress,
  ]);

  return {
    mockPriceFetcher,
    oracleAdapter,
    wormGame,
  };
});

export default WormGameModule;

