import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * 프로덕션용 배포 모듈 (Chainlink 오라클 사용)
 *
 * 배포 방법:
 * npx hardhat ignition deploy ignition/modules/WormGameProduction.ts --network <network-name> --parameters parameters-production.json
 */
const WormGameProductionModule = buildModule("WormGameProductionModule", (m) => {
  const serverSignerAddress = m.getParameter<string>(
    "serverSigner",
    process.env.SERVER_SIGNER_ADDRESS || "0x0000000000000000000000000000000000000000"
  );

  // 1. ChainlinkPriceFetcher 배포 (실제 오라클)
  const chainlinkPriceFetcher = m.contract("ChainlinkPriceFetcher");

  // 2. UserOnChainPriceOracleAdapter 배포
  const oracleAdapter = m.contract("UserOnChainPriceOracleAdapter", [
    chainlinkPriceFetcher,
  ]);

  // 3. WormGame 배포
  const wormGame = m.contract("WormGame", [
    oracleAdapter,
    serverSignerAddress,
  ]);

  return {
    chainlinkPriceFetcher,
    oracleAdapter,
    wormGame,
  };
});

export default WormGameProductionModule;
