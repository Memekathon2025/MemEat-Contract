import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * 프로덕션용 배포 모듈 (MemeX Bonding Curve 사용)
 *
 * 배포 방법:
 * npx hardhat ignition deploy ignition/modules/WormGameProduction.ts --network <network-name> --parameters parameters-production.json
 */
const WormGameProductionModule = buildModule("WormGameProductionModule", (m) => {
  const relayerAddress = m.getParameter<string>(
    "relayer",
    process.env.RELAYER_ADDRESS || "0x0000000000000000000000000000000000000000"
  );

  const bondingCurveAddress = m.getParameter<string>(
    "bondingCurve",
    "0x6a594a2C401Cf32D29823Ec10D651819DDfd688D" // MemeX Bonding Curve 주소
  );

  // 1. MemeXPriceFetcher 배포
  const memeXPriceFetcher = m.contract("MemeXPriceFetcher", [
    bondingCurveAddress,
  ]);

  // 2. WormGame 배포
  const wormGame = m.contract("WormGame", [relayerAddress]);

  return {
    memeXPriceFetcher,
    wormGame,
  };
});

export default WormGameProductionModule;
