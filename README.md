# WormGame - 실시간 가격 기반 게임 컨트랙트

## 📋 프로젝트 개요

WormGame은 **DEX Pool 실시간 가격**을 활용한 온체인 자산 정산 게임 컨트랙트입니다.

### 핵심 특징

- ✅ **실시간 DEX Pool 가격 조회** (Mock 사용 안 함)
- ✅ **상태 머신(State Machine)** 기반 설계
- ✅ **Relayer 패턴**으로 게임 로직 검증
- ✅ **재진입 공격 방지** (ReentrancyGuard)
- ✅ **멀티 토큰 보상** 지원
- ✅ **네이티브 M 또는 MRC-20 입장료** 지원

---

## 🎮 게임 흐름

```
1. 유저가 입장료 지불 (M 또는 MRC-20) → Active 상태
2. 오프체인에서 게임 플레이 (토큰 수집)
3. 백엔드가 실시간 DEX Pool 가격으로 총 가치 계산
   - 각 토큰의 현재 가격 조회
   - 총 가치 = Σ(토큰 수량 × 실시간 가격)
4. 탈출 조건 확인 (총 가치 >= 입장료)
   ├─ 조건 충족 → Relayer가 Exited 상태로 변경
   └─ 사망 → Dead 상태 (보상 없음)
5. Exited 유저가 claimReward() 호출 → Claimed 상태
```

---

## 🌐 배포 정보 (Formicarium Testnet)

### 배포된 컨트랙트
- **WormGame**: `0x10ea77b0ec7796a8b04a8db23551699a3ae5f086`
- **MemeXPriceFetcher**: `0x15902eb74b2124b7c67fda4fed571ce04797fff4`

### 네트워크 정보
- **Chain ID**: 43521
- **RPC URL**: https://rpc.formicarium.memecore.net
- **Explorer**: https://testnet.memecorescan.io/

### DEX Pool 주소 (가격 조회용)
- **WM/USDT Pool**: `0xdc010147c6597260c00a39b00ab618c0b6b0d5f4`
- **WM Token**: `0x653e645e3d81a72e71328bc01a04002945e3ef7a`
- **USDT Token**: `0xd7cfc924e629c4142cb6fa4f5467a7b8953e3de9`

---

## 💰 실시간 가격 조회

### 사용법

```bash
# WM/USDT 실시간 가격 조회
npm run price:pool
```

### 출력 예시

```
============================================================
💰 Formicarium Pool 실시간 가격 조회
============================================================

📍 컨트랙트 주소:
   WM:   0x653e645e3d81a72e71328bc01a04002945e3ef7a
   USDT: 0xd7cfc924e629c4142cb6fa4f5467a7b8953e3de9
   Pool: 0xdc010147c6597260c00a39b00ab618c0b6b0d5f4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 실시간 가격 정보
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 현재 가격:
   1 WM = 0.030740 USDT
   1 M  = 0.030740 USDT (WM과 동일)

📈 Pool 유동성:
   WM:   300,201.947 WM
   USDT: 9,228.318 USDT

🕐 마지막 업데이트:
   2025. 12. 4. 오후 3:56:39

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 조회 완료!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🚀 프론트엔드/백엔드 통합 가이드

### 1️⃣ 실시간 가격 조회 로직

핵심 파일: `scripts/get-pool-price.ts`

```typescript
// 1. Pool에서 Reserves 조회
const [reserve0, reserve1] = await publicClient.readContract({
  address: poolAddress,
  abi: parseAbi(["function getReserves() external view returns (uint112, uint112, uint32)"]),
  functionName: "getReserves",
});

// 2. token0 확인
const token0 = await publicClient.readContract({
  address: poolAddress,
  abi: parseAbi(["function token0() external view returns (address)"]),
  functionName: "token0",
});

// 3. 가격 계산
const isWMToken0 = token0.toLowerCase() === wmAddress.toLowerCase();
const wmReserve = isWMToken0 ? reserve0 : reserve1;
const usdtReserve = isWMToken0 ? reserve1 : reserve0;
const priceInUSDT = Number(usdtReserve) / Number(wmReserve);
```

### 2️⃣ 백엔드 구현 예시

```typescript
// 각 게임 토큰의 Pool 주소 매핑
const POOL_CONFIG = {
  "WM": {
    tokenAddress: "0x653e645e3d81a72e71328bc01a04002945e3ef7a",
    poolAddress: "0xdc010147c6597260c00a39b00ab618c0b6b0d5f4",
  },
  // 게임에서 사용되는 다른 토큰 추가
  // "sdf": { tokenAddress: "0x...", poolAddress: "0x..." },
};

// API: GET /api/token/:symbol/price
async function getTokenPrice(symbol: string) {
  const config = POOL_CONFIG[symbol];
  // get-pool-price.ts 로직 사용
  return { priceInUSDT: 0.030740 };
}

// 플레이어 총 가치 계산
async function calculatePlayerValue(playerAddress: string) {
  const tokens = await db.getPlayerTokens(playerAddress); // [{ symbol: "sdf", amount: 10 }]

  let totalValue = 0;
  for (const token of tokens) {
    const price = await getTokenPrice(token.symbol);
    totalValue += token.amount * price.priceInUSDT;
  }

  return totalValue;
}

// 탈출 조건 체크
async function checkExitCondition(playerAddress: string) {
  const player = await wormGameContract.read.players([playerAddress]);
  const totalValue = await calculatePlayerValue(playerAddress);

  return totalValue >= player.entryAmount;
}
```

### 3️⃣ 프론트엔드 구현 예시

```typescript
// 1초마다 실시간 가격 업데이트
setInterval(async () => {
  const response = await fetch(`/api/player/${playerAddress}/status`);
  const data = await response.json();

  // UI 업데이트
  document.getElementById('total-value').innerText =
    `${data.totalValue.toFixed(2)} M / ${data.entryAmount} M`;

  // Exit 버튼 활성화/비활성화
  const exitButton = document.getElementById('exit-button');
  if (data.canExit) {
    exitButton.disabled = false;
    exitButton.classList.add('active');
    showNotification('🎉 탈출 조건 달성!');
  } else {
    exitButton.disabled = true;
    exitButton.classList.remove('active');
  }
}, 1000);
```

### 4️⃣ 게임 토큰 추가 방법

1. Formicarium DEX에서 새 토큰의 Pool 주소 찾기
2. `scripts/get-pool-price.ts`를 수정하여 해당 Pool 테스트
3. 백엔드 `POOL_CONFIG`에 추가

---

## 📂 프로젝트 구조

```
MemEat-Contract/
├── contracts/
│   ├── WormGame.sol                    # 메인 게임 컨트랙트
│   ├── interfaces/
│   │   └── IWormGame.sol               # 인터페이스
│   ├── mocks/                          # 테스트용 Mock 컨트랙트
│   └── adapters/                       # 외부 프로토콜 어댑터
│
├── scripts/
│   ├── get-pool-price.ts               # ⭐ 실시간 가격 조회 스크립트
│   └── verify-deployment.ts            # 배포 검증
│
├── test/                               # 테스트 파일
├── ignition/                           # Hardhat Ignition 배포 설정
├── hardhat.config.ts                   # Hardhat 설정 (Formicarium)
├── package.json                        # 의존성 관리
├── tsconfig.json                       # TypeScript 설정
└── README.md                           # 이 파일
```

---

## 🎲 게임 메커니즘 (가격 변동)

### 핵심: Exit 버튼의 동적 활성화/비활성화

```
[00:30] 게임 시작
획득: sdf 7개
가격: 0.12 M/개
총 가치: 0.84 M / 1.0 M (84%)
UI: [🚫 탈출 불가]

[01:15] sdf 가격 상승! ⬆️
획득: sdf 7개 (그대로)
가격: 0.15 M/개
총 가치: 1.05 M / 1.0 M (105%) ✅
UI: [🚪 탈출하기] ← 버튼 활성화!

[02:00] sdf 가격 폭락! ⬇️
획득: sdf 10개
가격: 0.08 M/개
총 가치: 0.80 M / 1.0 M (80%) ❌
UI: [🚫 탈출 불가] ← 버튼 비활성화
```

**게임의 재미 요소:**
- 실시간 가격 변동으로 긴장감 조성
- 탈출 타이밍 선택 (안전 vs 욕심)
- 여러 토큰 수집 전략 (포트폴리오)

---

## 🛠️ 주요 함수

### 유저 함수

#### `enterGame(token, amount)`
- **입장료 지불**: Native M (msg.value) 또는 MRC-20 토큰
- **수수료**: 5% (Treasury로 전송)
- **상태**: Active

#### `claimReward()`
- **보상 정산**: Exited 상태에서만 가능
- **토큰 전송**: 획득한 모든 토큰 인출
- **상태**: Claimed

### Relayer 함수

#### `updateGameState(player, newStatus, rewardTokens, rewardAmounts)`
- **게임 종료**: Exited 또는 Dead 상태로 변경
- **권한**: Relayer만
- **조건**: 백엔드가 실시간 가격으로 탈출 조건 검증 후 호출

### View 함수

- `getPlayerStatus(player)`: 플레이어 상태 조회
- `getPlayerReward(player)`: 보상 정보 조회
- `getContractBalance(token)`: 컨트랙트 잔액 조회

---

## 🚀 실행 방법

### 사전 요구사항

- Node.js 18.x 이상
- npm 또는 yarn

### 설치

```bash
cd MemEat-Contract
npm install
```

### 환경 변수 설정

`.env` 또는 `.env.local` 파일을 생성하고 다음 내용을 설정합니다:

```env
# 배포 계정 Private Key
INSECTARIUM_PRIVATE_KEY=your_private_key_here
```

### 컴파일

```bash
npx hardhat compile
```

### 테스트

```bash
npm test
# 또는
npx hardhat test
```

### 배포

#### Hardhat 네트워크 설정

[hardhat.config.ts](hardhat.config.ts)에 정의된 네트워크:

- **insectarium**: Memecore Testnet (Chain ID: 43522)
  - RPC: https://rpc.insectarium.memecore.net

- **formicarium**: Memecore Testnet (Chain ID: 43521)
  - RPC: https://rpc.formicarium.memecore.net

- **memecore**: Memecore Mainnet (Chain ID: 4352)
  - RPC: https://rpc.memecore.net

#### 배포 명령어

```bash
# Formicarium 테스트넷에 배포
npx hardhat ignition deploy ignition/modules/WormGame.ts --network formicarium

# Insectarium 테스트넷에 배포
npx hardhat ignition deploy ignition/modules/WormGame.ts --network insectarium

# Memecore 메인넷에 배포
npx hardhat ignition deploy ignition/modules/WormGame.ts --network memecore
```

### 배포 후 ABI 업데이트

컨트랙트 배포 후 생성된 ABI를 프론트엔드와 백엔드에 복사합니다:

```bash
# ABI 위치: artifacts/contracts/WormGame.sol/WormGame.json
# 백엔드로 복사
cp artifacts/contracts/WormGame.sol/WormGame.json ../MemEat-BE/src/abis/

# 프론트엔드로 복사
cp artifacts/contracts/WormGame.sol/WormGame.json ../MemEat-FE/src/abis/
```

---

## 🔒 보안

- ✅ **재진입 공격 방지**: ReentrancyGuard + CEI 패턴
- ✅ **권한 관리**: onlyRelayer, onlyOwner
- ✅ **상태 검증**: 모든 상태 전이 검증

---

## 📞 지원

- **GitHub Issues**: 버그 리포트 및 기능 요청
- **테스트넷**: Formicarium에서 충분히 테스트 후 사용

---

**WormGame은 실시간 DEX 가격 기반 게임입니다!** 🐛💰
