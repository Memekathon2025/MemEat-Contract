# WormGame - 상태 머신 기반 게임 컨트랙트

## 📋 프로젝트 개요

WormGame은 **오프체인 게임 로직**과 **온체인 자산 정산**을 결합한 하이브리드 게임 컨트랙트입니다.

### 핵심 특징
- ✅ **상태 머신(State Machine)** 기반 설계 (5개 상태)
- ✅ **Relayer 패턴**으로 서버 권한 관리
- ✅ **재진입 공격 방지** (CEI 패턴 + ReentrancyGuard)
- ✅ **게임 세션 추적** (gameId)
- ✅ **멀티 토큰 보상** 지원

---

## 🎮 게임 흐름

```
1. 유저가 입장료 지불 → Active 상태
2. 오프체인에서 게임 플레이
3. 게임 종료 시 Relayer(서버)가 결과 기록
   ├─ 탈출 성공 → Exited 상태 (보상 기록)
   └─ 사망 → Dead 상태 (보상 없음)
4. Exited 유저만 정산(claimReward) 가능 → Claimed 상태
5. Dead/Claimed 상태에서 재진입 가능 → 다시 Active
```

---

## 📂 프로젝트 구조

```
worm-contract/
├── contracts/
│   ├── WormGame.sol                          # 메인 게임 컨트랙트
│   ├── UserOnChainPriceOracleAdapter.sol     # 가격 오라클 어댑터
│   ├── adapters/                             # 오라클 어댑터들
│   │   ├── ChainlinkPriceFetcher.sol        # Chainlink 오라클 (프로덕션)
│   │   └── (기타 오라클 구현체)
│   ├── interfaces/
│   │   └── IPriceFetcher.sol                # 오라클 인터페이스
│   └── mocks/
│       ├── MockERC20.sol                     # 테스트용 토큰
│       └── MockPriceFetcher.sol              # 테스트용 오라클
│
├── test/
│   └── WormGame.test.ts                      # 통합 테스트 (13개)
│
├── ignition/modules/
│   ├── WormGame.ts                           # 테스트넷 배포 (Mock 오라클)
│   └── WormGameProduction.ts                 # 프로덕션 배포 (Chainlink)
│
├── 문서/
│   ├── README.md                             # 이 파일 (프로젝트 가이드)
│   ├── WORMGAME_SUMMARY.md                   # 전체 요약 및 요구사항
│   ├── STATE_MACHINE.md                      # 상태 머신 다이어그램
│   └── SECURITY_AUDIT.md                     # 보안 검증 문서
│
└── 설정 파일/
    ├── parameters.json                       # 배포 파라미터
    ├── hardhat.config.ts                     # Hardhat 설정
    ├── package.json                          # 의존성 관리
    └── .env                                  # 환경 변수 (git ignore)
```

---

## 🚀 빠른 시작

### 1. 의존성 설치

```bash
npm install
```

### 2. 환경 변수 설정

`.env` 파일 생성:

```bash
# 배포 지갑 Private Key
INSECTARIUM_PRIVATE_KEY=0x...

# Relayer 주소 (게임 서버 지갑)
RELAYER_ADDRESS=0x...
```

### 3. 배포 파라미터 설정

[parameters.json](parameters.json) 파일 수정:

```json
{
  "WormGameModule": {
    "relayer": "0x...",              // Relayer 주소
    "minExitValue": "50000000000000000000"  // 최소 탈출 가치 (50 USD)
  }
}
```

### 4. 컴파일

```bash
npx hardhat compile
```

### 5. 테스트 실행

```bash
npm test
```

**예상 결과:**
```
WormGame (State Machine)
  🎮 Entry Flow (입장)
    ✔ Should allow player to enter game
    ✔ Should prevent entering with 0 amount
    ✔ Should prevent entering while already active
  🎯 Exit Flow (탈출)
    ✔ Should allow Relayer to mark player as Exited
    ✔ Should prevent non-Relayer from updating state
  💰 Claim Flow (정산)
    ✔ Should allow Exited player to claim rewards
    ✔ Should prevent Active player from claiming
    ✔ Should prevent Dead player from claiming
    ✔ Should prevent double claiming
  ☠️ Death Flow (사망)
    ✔ Should handle player death correctly
    ✔ Should allow re-entry after death
  🔧 Admin Functions (관리자)
    ✔ Should allow owner to change Relayer
    ✔ Should allow owner to change minExitValue

  13 passing
```

### 6. 배포

#### 테스트넷 (Insectarium)

```bash
npx hardhat ignition deploy ignition/modules/WormGame.ts \
  --network insectarium \
  --parameters parameters.json
```

#### 프로덕션

```bash
npx hardhat ignition deploy ignition/modules/WormGameProduction.ts \
  --network <network-name> \
  --parameters parameters.json
```

---

## 📖 코드 흐름 상세 설명

### Phase 1: 컴파일 및 테스트

```
1. npx hardhat compile
   └─ Solidity 컨트랙트를 bytecode로 컴파일
   └─ artifacts/ 폴더에 ABI와 bytecode 생성

2. npm test
   └─ test/WormGame.test.ts 실행
   └─ 로컬 Hardhat 네트워크에 임시 배포
   └─ 13개 테스트 시나리오 검증
```

### Phase 2: 배포 (Deployment)

```
npx hardhat ignition deploy ignition/modules/WormGame.ts
   ↓
[Step 1] ignition/modules/WormGame.ts 실행
   ├─ parameters.json에서 설정값 읽기
   │  ├─ relayer: Relayer 주소
   │  └─ minExitValue: 최소 탈출 가치
   │
   ├─ [배포 1] MockERC20 (테스트용 토큰)
   ├─ [배포 2] MockPriceFetcher (테스트용 오라클)
   ├─ [배포 3] UserOnChainPriceOracleAdapter
   │              └─ 생성자에 MockPriceFetcher 주소 전달
   └─ [배포 4] WormGame
                 ├─ 생성자 파라미터:
                 │  ├─ relayer: Relayer 주소
                 │  └─ minExitValue: 50 USD
                 └─ 상속: Ownable, ReentrancyGuard

[Step 2] 배포 완료
   └─ ignition/deployments/chain-<chainId>/deployed_addresses.json 생성
   └─ 배포된 주소 저장
```

### Phase 3: 게임 실행 (Runtime)

#### 3-1. 유저 입장 (enterGame)

```solidity
// 클라이언트 → WormGame 컨트랙트
enterGame(tokenAddress, amount)
   ↓
[검증]
├─ amount > 0인지 확인
├─ 이미 Active 상태가 아닌지 확인
└─ 이전 게임이 종료되었으면 데이터 초기화

[토큰 전송]
└─ IERC20(token).transferFrom(user, contract, amount)
   └─ 유저 지갑 → WormGame 컨트랙트

[상태 변경]
├─ gameIdCounter++
├─ status = Active
├─ gameId = gameIdCounter
└─ emit GameEntered(...)

[결과]
└─ 유저는 이제 게임 플레이 가능 (오프체인)
```

#### 3-2. 게임 플레이 (오프체인)

```
[클라이언트 ↔ 게임 서버]
└─ WebSocket/HTTP로 게임 진행
└─ 서버는 게임 로직 처리
   ├─ 벌레 움직임
   ├─ 아이템 수집
   ├─ 자산 가치 계산
   └─ 탈출/사망 판정
```

#### 3-3. 게임 종료 (updateGameState)

```solidity
// 게임 서버(Relayer) → WormGame 컨트랙트
updateGameState(playerAddress, newStatus, rewardTokens, rewardAmounts)
   ↓
[권한 검증]
└─ if (msg.sender != relayer) revert OnlyRelayer()
   └─ 일반 유저는 호출 불가!

[상태 검증]
├─ player.status == Active인지 확인
└─ newStatus가 Exited 또는 Dead인지 확인

[상태 변경]
├─ if (newStatus == Exited):
│  ├─ status = Exited
│  ├─ rewardTokens = [토큰 주소들]
│  └─ rewardAmounts = [보상 수량들]
└─ else if (newStatus == Dead):
   ├─ status = Dead
   └─ rewardTokens/Amounts = [] (빈 배열)

[결과]
├─ Exited: 유저는 claimReward() 호출 가능
└─ Dead: 정산 불가, 재진입만 가능
```

#### 3-4. 보상 정산 (claimReward)

```solidity
// 유저 → WormGame 컨트랙트
claimReward()
   ↓
[검증] Checks
├─ status == Exited인지 확인
│  ├─ Active → ❌ NotExited
│  ├─ Dead → ❌ NotExited
│  └─ Claimed → ❌ NotExited
└─ rewardTokens.length > 0인지 확인

[상태 변경] Effects (재진입 방지!)
└─ status = Claimed
   └─ 먼저 상태를 변경하여 중복 정산 차단

[토큰 전송] Interactions
└─ for (각 보상 토큰):
   └─ IERC20(rewardTokens[i]).transfer(user, rewardAmounts[i])
      └─ WormGame 컨트랙트 → 유저 지갑

[결과]
└─ 유저가 보상을 받고 게임 종료
```

---

## 🔒 보안 메커니즘

### 1. Dead 상태 정산 차단

```solidity
if (player.status != PlayerStatus.Exited) {
    revert NotExited();
}
```

**원리**: Dead는 Exited가 아니므로 자동 차단

### 2. Active 상태 정산 차단

```
유저는 updateGameState()를 호출할 수 없음 (onlyRelayer)
     ↓
Active → Exited 전환 불가능
     ↓
claimReward() 호출 시 NotExited 에러
```

### 3. 중복 정산 방지

**Checks-Effects-Interactions 패턴:**

```solidity
// 1. Checks: 상태 확인
if (status != Exited) revert;

// 2. Effects: 먼저 상태 변경 (중요!)
status = Claimed;

// 3. Interactions: 그 후 토큰 전송
transfer(...);
```

**재진입 공격 시나리오:**

```
악의적 토큰 컨트랙트:
1. claimReward() 호출
2. transfer() 시 악의적 receive() 훅 실행
3. receive()에서 다시 claimReward() 호출 시도
   ↓
   이미 status == Claimed이므로 NotExited 에러!
```

**추가 방어선: ReentrancyGuard**

```solidity
function claimReward() external nonReentrant {
    // nonReentrant modifier가 재진입 차단
}
```

---

## 📊 상태 전이 다이어그램

```
    [None]
      ↓ enterGame()
   [Active] ← 게임 진행 (오프체인)
      ↓
      ├─ updateGameState(Exited) → [Exited] → claimReward() → [Claimed]
      │                                                              ↓
      └─ updateGameState(Dead) → [Dead] ←────────────────────────────┘
                                    ↓                   재진입
                                    └─ enterGame() → [Active]
```

**허용되는 전이:**
- None → Active (enterGame)
- Active → Exited (updateGameState, Relayer만)
- Active → Dead (updateGameState, Relayer만)
- Exited → Claimed (claimReward)
- Dead → Active (enterGame, 재진입)
- Claimed → Active (enterGame, 재진입)

**차단되는 전이:**
- Active → Active (AlreadyInGame)
- Active → Claimed (updateGameState 없이 불가능)
- Dead → Exited (사망 후 탈출 불가)
- Dead → Claimed (NotExited)

---

## 🛠️ 주요 함수 설명

### 유저 호출 함수

#### `enterGame(token, amount)`
- **목적**: 게임 입장 및 입장료 지불
- **권한**: 누구나
- **조건**: amount > 0, Active 상태 아님
- **결과**: Active 상태로 변경

#### `claimReward()`
- **목적**: 탈출 성공 시 보상 정산
- **권한**: Exited 상태인 유저만
- **조건**: status == Exited, 보상 배열 존재
- **결과**: Claimed 상태로 변경 + 토큰 전송

### Relayer 호출 함수

#### `updateGameState(player, newStatus, rewardTokens, rewardAmounts)`
- **목적**: 게임 결과 기록
- **권한**: Relayer만
- **조건**: player.status == Active, newStatus == Exited/Dead
- **결과**: Exited 또는 Dead 상태로 변경

### 관리자 함수

#### `setRelayer(newRelayer)`
- **목적**: Relayer 주소 변경
- **권한**: Owner만

#### `setMinExitValue(newValue)`
- **목적**: 최소 탈출 가치 변경
- **권한**: Owner만

### View 함수

#### `getPlayerStatus(player) → PlayerStatus`
- 플레이어 현재 상태 조회

#### `getPlayerReward(player) → (tokens[], amounts[])`
- 플레이어 보상 정보 조회

#### `getContractBalance(token) → uint256`
- 컨트랙트의 토큰 잔액 조회

---

## 📚 추가 문서

- **[WORMGAME_SUMMARY.md](WORMGAME_SUMMARY.md)**: 전체 프로젝트 요약 및 배포 가이드
- **[STATE_MACHINE.md](STATE_MACHINE.md)**: 상태 머신 상세 설명 및 Mermaid 다이어그램
- **[SECURITY_AUDIT.md](SECURITY_AUDIT.md)**: 보안 검증 및 공격 벡터 분석

---

## ⚠️ 주의사항

### Relayer 키 관리

```
❗ Relayer 개인키는 절대 노출되어서는 안 됩니다!

권장 사항:
✅ 하드웨어 월렛 사용
✅ AWS KMS 등 키 관리 서비스 사용
✅ 멀티시그 Relayer (향후 업그레이드)
```

### minExitValue 설정

```
minExitValue가 너무 낮으면:
❌ 소액으로 탈출 가능 → 게임성 저하

minExitValue가 너무 높으면:
❌ 탈출 불가능 → 유저 불만

권장:
✅ 입장료의 5~10배 수준
✅ 시장 상황에 따라 조정 가능
```

---

## 📞 지원

질문이나 이슈가 있으시면:
1. GitHub Issues 생성
2. 보안 감사 전문가 상담
3. 테스트넷에서 충분히 테스트 후 배포

---

**WormGame은 프로덕션 준비가 완료되었습니다!** 🎉
