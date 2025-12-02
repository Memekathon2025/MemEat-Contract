import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

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

  const minExitValue = m.getParameter<bigint>(
    "minExitValue",
    parseEther("50") // 기본값: 50 USD
  );

  // WormGame 배포
  const wormGame = m.contract("WormGame", [relayerAddress, minExitValue]);

  return {
    wormGame,
  };
});

export default WormGameModule;
