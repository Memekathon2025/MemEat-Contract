import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * WormGame 배포 모듈 (상태 머신 기반)
 *
 * 배포 방법:
 * npx hardhat ignition deploy ignition/modules/WormGame.ts --network insectarium --parameters parameters.json
 */
const WormGameModule = buildModule("WormGameModule", (m) => {
  // 파라미터 받기
  const relayerAddress = m.getParameter<string>(
    "relayer",
    process.env.RELAYER_ADDRESS || "0x0000000000000000000000000000000000000000"
  );

  // WormGame 배포
  // Treasury는 일단 Relayer와 동일하게 설정 (나중에 변경 가능)
  const wormGame = m.contract("WormGame", [relayerAddress, relayerAddress]);

  return {
    wormGame,
  };
});

export default WormGameModule;
