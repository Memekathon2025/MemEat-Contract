# WormGame 아키텍처 설계서

## 📋 개요

WormGame은 온체인 상태 관리와 오프체인 게임 로직을 결합한 하이브리드 게임입니다.

### 핵심 특징
- **상태 머신 기반**: 플레이어 상태를 5단계로 관리 (NotStarted → Active → Exited/Dead → Claimed)
- **Relayer 패턴**: 백엔드가 게임 결과를 검증하고 온체인에 기록
- **멀티 토큰 보상**: 다양한 MRC-20 토큰을 획득하고 정산 가능

---

## 🎮 게임 플로우

### 1. 입장 (Entry)
```
유저 → enterGame(token, amount) → WormGame 컨트랙트
```
- 입장료(M 토큰)를 지불하고 게임 시작
- 상태: `NotStarted` → `Active`
- DB에 게임 세션 생성

### 2. 게임 플레이 (In-Game)
```
WebSocket ↔ 백엔드 게임 엔진
```
- 실시간 이동, 충돌 감지, 아이템(토큰) 획득
- 획득한 토큰은 DB의 `PlayerInventory`에 저장
- 백엔드가 실시간으로 총 가치 계산 (`TotalValue`)

### 3. 탈출 조건 검증 (Exit Validation)
```
백엔드 → MemeXPriceFetcher → Bonding Curve (가격 조회)
```

**탈출 조건**:
```
획득한 모든 토큰의 총 M 환산 가치 >= 입장료(entryAmount)
```

**계산 예시**:
```
입장료: 1 M

획득 토큰:
- sdf 100개 × 0.005 M/개 = 0.5 M
- z 20개 × 0.05 M/개 = 1.0 M
---------------------------------
총 가치: 1.5 M

1.5 M >= 1 M → ✅ 탈출 가능
```

### 4-A. 탈출 성공 (Exit)
```
유저 탈출 요청 → 백엔드 검증 → Relayer → updateGameState(Exited)
```
- 조건: 생존 상태 + 총 가치 >= 입장료
- 상태: `Active` → `Exited`
- 보상 토큰 정보가 온체인에 기록됨

### 4-B. 사망 (Death)
```
충돌 감지 → 백엔드 → Relayer → updateGameState(Dead)
```
- 벽, 장애물, 다른 플레이어와 충돌 시
- 상태: `Active` → `Dead`
- 보상 없음 (빈 배열로 기록)

### 5. 보상 정산 (Claim)
```
유저 → claimReward() → WormGame 컨트랙트
```
- 조건: `Exited` 상태만 가능
- 온체인에 기록된 보상 토큰들을 유저 지갑으로 전송
- 상태: `Exited` → `Claimed`

---

## 🏗️ 컨트랙트 구조

### WormGame.sol
**역할**: 게임 상태 관리 및 토큰 정산

**주요 함수**:
- `enterGame()`: 유저가 입장료 지불하고 게임 시작
- `updateGameState()`: Relayer만 호출 가능, 게임 결과 기록 (Exited/Dead)
- `claimReward()`: 유저가 보상 토큰 수령

**상태 변수**:
- `relayer`: 백엔드 서버 주소 (게임 결과를 기록할 권한)
- `players`: 플레이어 정보 매핑

### MemeXPriceFetcher.sol
**역할**: MemeX Bonding Curve에서 토큰 가격 조회

**Bonding Curve 주소**: `0x6a594a2C401Cf32D29823Ec10D651819DDfd688D`

**가격 조회 메서드** (순차 시도):
1. `getCurrentPrice()`
2. `getBuyPrice(uint256)`
3. `price()`

---

## 💾 백엔드 데이터베이스 스키마

### GameSessions
| 컬럼 | 타입 | 설명 |
|------|------|------|
| gameId | Uint256 (PK) | 컨트랙트의 gameId와 동기화 |
| playerAddress | String | 유저 지갑 주소 |
| status | Enum | Active / Exited / Dead / Claimed |
| entryToken | String | 입장료 토큰 주소 |
| entryAmount | Uint256 | 입장료 수량 |
| totalValue | Uint256 | 획득 토큰의 M 환산 총 가치 (실시간 업데이트) |
| startTime | Timestamp | 게임 시작 시간 |
| endTime | Timestamp | 게임 종료 시간 |

### PlayerInventory
| 컬럼 | 타입 | 설명 |
|------|------|------|
| sessionId | FK | GameSessions 참조 |
| tokenAddress | String | 획득한 토큰 주소 |
| amount | Uint256 | 획득 수량 |

---

## 🔐 보안 고려사항

### 1. Relayer 권한 관리
- `updateGameState()`는 `onlyRelayer` modifier로 보호됨
- Relayer 개인키 유출 시 임의로 보상 지급 가능
- **해결책**: AWS KMS, HashiCorp Vault 등 Key Management Service 사용

### 2. 재진입 공격 방지
- `ReentrancyGuard` 사용
- `claimReward()`에서 상태 변경 → 토큰 전송 순서 보장 (CEI 패턴)

### 3. 잔고 검증
- 백엔드는 유저가 획득한 토큰 양이 실제 컨트랙트 잔고를 초과하지 않는지 검증
- `getContractBalance(token)` 함수 활용

### 4. Nonce 관리
- 동시 다발적 트랜잭션 발생 시 Nonce 충돌 방지
- 트랜잭션 큐 시스템 구축 필요

---

## 📊 가스 최적화

### 현재 비용 구조
- `enterGame()`: 유저 부담
- `updateGameState()`: Relayer(운영사) 부담 ⚠️
- `claimReward()`: 유저 부담

### 최적화 방안
1. 사망 처리 배치(Batch) 처리 검토
2. 보상 토큰 배열 길이 제한
3. 이벤트 로그 최소화

---

## 🚀 배포 방법

### 테스트넷 배포
```bash
npx hardhat ignition deploy ignition/modules/WormGame.ts \
  --network insectarium \
  --parameters parameters.json
```

### 프로덕션 배포
```bash
npx hardhat ignition deploy ignition/modules/WormGameProduction.ts \
  --network <mainnet> \
  --parameters parameters-production.json
```

**파라미터 파일 예시** (`parameters.json`):
```json
{
  "WormGameModule": {
    "relayer": "0xYourRelayerAddress"
  }
}
```

---

## 🧪 테스트

```bash
# 모든 테스트 실행
npx hardhat test

# 특정 테스트만 실행
npx hardhat test test/WormGame.test.ts
```

**테스트 커버리지**:
- ✅ 입장 플로우 (3개 테스트)
- ✅ 탈출 플로우 (2개 테스트)
- ✅ 정산 플로우 (4개 테스트)
- ✅ 사망 플로우 (2개 테스트)
- ✅ 관리자 함수 (1개 테스트)

---

## 📝 이벤트 모니터링

### GameEntered
```solidity
event GameEntered(
    address indexed player,
    address token,
    uint256 amount,
    uint256 gameId,
    uint256 timestamp
)
```
→ 백엔드 Indexer가 감지하여 게임 세션 생성

### GameStateUpdated
```solidity
event GameStateUpdated(
    address indexed player,
    PlayerStatus newStatus,
    uint256 gameId,
    address[] rewardTokens,
    uint256[] rewardAmounts
)
```
→ 탈출 성공 또는 사망 시 발생

### RewardClaimed
```solidity
event RewardClaimed(
    address indexed player,
    uint256 gameId,
    address[] tokens,
    uint256[] amounts
)
```
→ 유저가 보상 수령 완료 시 발생

---

## 🔄 상태 전이 다이어그램

```
NotStarted (0)
    ↓ enterGame()
Active (1)
    ↓
    ├─→ Exited (2) ← updateGameState(Exited) [탈출 조건 만족]
    │      ↓ claimReward()
    │   Claimed (4)
    │
    └─→ Dead (3) ← updateGameState(Dead) [충돌 감지]
           ↓ 재입장 가능
        NotStarted (0)
```

---

## 📞 문의

컨트랙트 관련 문의: [Repository Issues](../../issues)
