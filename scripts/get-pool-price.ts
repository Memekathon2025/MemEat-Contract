import { createPublicClient, http, parseAbi, formatEther } from "viem";

/**
 * Pool에서 직접 가격 조회
 * 트랜잭션 분석으로 찾은 정확한 주소 사용
 */

/**
 * ============================================
 * 🎯 실시간 Pool 가격 조회 스크립트
 * ============================================
 *
 * 📌 사용법:
 *    npm run price:pool
 *
 * 📌 프론트/백엔드 구현 가이드:
 *
 * 1. 이 스크립트의 핵심 로직:
 *    - Pool 컨트랙트에서 getReserves() 호출
 *    - Reserve 비율로 가격 계산: price = usdtReserve / wmReserve
 *
 * 2. 백엔드 구현 시:
 *    - viem의 createPublicClient + readContract 사용
 *    - 각 게임 토큰마다 Pool 주소 매핑 필요
 *    - 예: { "sdf": "0x...", "z": "0x..." }
 *
 * 3. 실시간 업데이트:
 *    - API: GET /api/token/:symbol/price
 *    - 프론트: 1초마다 polling 또는 WebSocket
 *
 * 4. 게임 토큰 추가 시:
 *    - 해당 토큰의 Pool 주소를 찾아서 동일한 방식으로 조회
 *    - Formicarium DEX에서 토큰/WM 페어 주소 확인
 *
 * ============================================
 */

async function main() {
  console.log("=".repeat(60));
  console.log("💰 Formicarium Pool 실시간 가격 조회");
  console.log("=".repeat(60));

  const formicarium = {
    id: 43521,
    name: 'Formicarium',
    nativeCurrency: { name: 'M', symbol: 'M', decimals: 18 },
    rpcUrls: {
      default: { http: ['https://rpc.formicarium.memecore.net'] },
      public: { http: ['https://rpc.formicarium.memecore.net'] },
    },
  } as const;

  const publicClient = createPublicClient({
    chain: formicarium,
    transport: http('https://rpc.formicarium.memecore.net'),
  });

  // WM/USDT Pool 주소
  const wmAddress = "0x653e645e3d81a72e71328bc01a04002945e3ef7a" as `0x${string}`;
  const usdtAddress = "0xd7cfc924e629c4142cb6fa4f5467a7b8953e3de9" as `0x${string}`;
  const poolAddress = "0xdc010147c6597260c00a39b00ab618c0b6b0d5f4" as `0x${string}`;

  console.log(`\n📍 컨트랙트 주소:`);
  console.log(`   WM:   ${wmAddress}`);
  console.log(`   USDT: ${usdtAddress}`);
  console.log(`   Pool: ${poolAddress}\n`);

  try {
    const pairAbi = parseAbi([
      "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
      "function token0() external view returns (address)",
      "function token1() external view returns (address)"
    ]);

    // Pool에서 Reserves 조회
    const [reserve0, reserve1, timestamp] = await publicClient.readContract({
      address: poolAddress,
      abi: pairAbi,
      functionName: "getReserves",
    }) as [bigint, bigint, number];

    const token0 = await publicClient.readContract({
      address: poolAddress,
      abi: pairAbi,
      functionName: "token0",
    }) as `0x${string}`;

    // 가격 계산
    const isWMToken0 = token0.toLowerCase() === wmAddress.toLowerCase();
    const wmReserve = isWMToken0 ? reserve0 : reserve1;
    const usdtReserve = isWMToken0 ? reserve1 : reserve0;

    // 가격 = USDT Reserve / WM Reserve
    const price = Number(usdtReserve) / Number(wmReserve);

    console.log("━".repeat(60));
    console.log("📊 실시간 가격 정보");
    console.log("━".repeat(60));
    console.log(`\n💰 현재 가격:`);
    console.log(`   1 WM = ${price.toFixed(6)} USDT`);
    console.log(`   1 M  = ${price.toFixed(6)} USDT (WM과 동일)`);

    console.log(`\n📈 Pool 유동성:`);
    console.log(`   WM:   ${Number(formatEther(wmReserve)).toLocaleString()} WM`);
    console.log(`   USDT: ${Number(formatEther(usdtReserve)).toLocaleString()} USDT`);

    console.log(`\n🕐 마지막 업데이트:`);
    console.log(`   ${new Date(timestamp * 1000).toLocaleString()}`);

    console.log("\n" + "━".repeat(60));
    console.log("✅ 조회 완료!");
    console.log("━".repeat(60));

    // JSON 형식 출력 (백엔드 API 응답 예시)
    console.log(`\n💡 백엔드 API 응답 예시:\n`);
    const apiResponse = {
      success: true,
      data: {
        tokenSymbol: "WM",
        priceInUSDT: parseFloat(price.toFixed(6)),
        reserves: {
          wm: formatEther(wmReserve),
          usdt: formatEther(usdtReserve)
        },
        lastUpdate: timestamp,
        poolAddress: poolAddress
      }
    };
    console.log(JSON.stringify(apiResponse, null, 2));

  } catch (error: any) {
    console.log(`\n❌ 오류 발생: ${error.message}`);
    console.log(`\n💡 확인사항:`);
    console.log(`   1. RPC 연결 상태 확인`);
    console.log(`   2. Pool 주소가 올바른지 확인`);
    console.log(`   3. 네트워크: Formicarium (Chain ID: 43521)`);
  }
}

main().catch(console.error);
