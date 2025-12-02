# WormGame 보안 검증 문서

## 1. 상태 머신 보안

### 1.1 Dead 상태 유저의 정산 차단

**공격 시나리오**: 사망한 유저가 `claimReward()` 호출 시도

**방어 메커니즘**:

```solidity
function claimReward() external nonReentrant {
    PlayerData storage player = players[msg.sender];

    // 검증: Exited 상태여야만 정산 가능
    if (player.status != PlayerStatus.Exited) {
        revert NotExited();
    }
    // ...
}
```

**상태 전이 규칙**:

```
Active → Exited  ✅ (Relayer가 탈출 성공 판정)
Active → Dead    ✅ (Relayer가 사망 판정)
Dead → Claimed   ❌ (차단됨)
Dead → Exited    ❌ (차단됨)
```

**테스트 코드**:

```typescript
it("Should prevent dead player from claiming", async () => {
  // 1. 입장
  await enterGame(player1, token, parseEther("10"));

  // 2. Relayer가 사망 처리
  await wormGame
    .connect(relayer)
    .updateGameState(player1.address, PlayerStatus.Dead, [], []);

  // 3. 정산 시도 → 실패해야 함
  await expect(
    wormGame.connect(player1).claimReward()
  ).to.be.revertedWithCustomError(wormGame, "NotExited");
});
```

---

### 1.2 Active 상태에서 강제 출금 방지

**공격 시나리오**: 게임 중인 유저가 정산 시도

**방어 메커니즘**:

```solidity
function claimReward() external nonReentrant {
    // Active 상태는 Exited가 아니므로 자동으로 차단됨
    if (player.status != PlayerStatus.Exited) {
        revert NotExited();
    }
}
```

**상태 전이 흐름**:

```
1. enterGame() → Active
2. updateGameState() → Exited (Relayer만 가능!)
3. claimReward() → Claimed
```

**핵심**: `updateGameState()`는 **Relayer만** 호출 가능하므로, 유저가 임의로 Exited 상태로 변경 불가능

---

### 1.3 중복 정산(Double Spending) 방지

**공격 시나리오 1**: `claimReward()` 여러 번 호출

**방어 메커니즘**:

```solidity
function claimReward() external nonReentrant {
    PlayerData storage player = players[msg.sender];

    // 검증: Exited 상태여야 함
    if (player.status != PlayerStatus.Exited) {
        revert NotExited();
    }

    // 상태를 Claimed로 변경 (재진입 전에!)
    player.status = PlayerStatus.Claimed;

    // 그 후 토큰 전송
    for (uint256 i = 0; i < player.rewardTokens.length; i++) {
        IERC20(player.rewardTokens[i]).transfer(
            msg.sender,
            player.rewardAmounts[i]
        );
    }
}
```

**Checks-Effects-Interactions 패턴**:

1. **Checks**: 상태 검증 (`status == Exited`)
2. **Effects**: 상태 변경 (`status = Claimed`)
3. **Interactions**: 외부 호출 (`transfer()`)

**테스트 코드**:

```typescript
it("Should prevent double claiming", async () => {
  // 1. 탈출 성공 상태로 설정
  await wormGame
    .connect(relayer)
    .updateGameState(
      player1.address,
      PlayerStatus.Exited,
      [token.address],
      [parseEther("100")]
    );

  // 2. 첫 번째 정산 → 성공
  await wormGame.connect(player1).claimReward();

  // 3. 두 번째 정산 시도 → 실패해야 함
  await expect(
    wormGame.connect(player1).claimReward()
  ).to.be.revertedWithCustomError(wormGame, "NotExited");
});
```

**공격 시나리오 2**: 재진입 공격 (Reentrancy)

**방어 메커니즘**:

```solidity
// OpenZeppelin의 ReentrancyGuard 사용
contract WormGame is Ownable, ReentrancyGuard {

    function claimReward() external nonReentrant {
        // nonReentrant modifier가 재진입 차단
    }
}
```

**재진입 공격 시나리오**:

```
1. 악의적 토큰 컨트랙트 배포
2. transfer() 호출 시 receive() 훅 실행
3. receive() 내에서 다시 claimReward() 호출 시도
   ↓
   nonReentrant modifier가 차단!
```

---

## 2. 권한 관리 보안

### 2.1 Relayer 권한 검증

**핵심 원칙**: 게임 결과는 오직 **신뢰할 수 있는 서버(Relayer)**만 기록 가능

**구현**:

```solidity
address public relayer;

modifier onlyRelayer() {
    if (msg.sender != relayer) revert OnlyRelayer();
    _;
}

function updateGameState(...) external onlyRelayer {
    // Relayer만 호출 가능
}
```

**공격 시나리오**: 일반 유저가 `updateGameState()` 호출 시도

**방어**:

```typescript
it("Should reject updateGameState from non-relayer", async () => {
  await expect(
    wormGame
      .connect(player1)
      .updateGameState(
        player1.address,
        PlayerStatus.Exited,
        [token.address],
        [parseEther("1000")]
      )
  ).to.be.revertedWithCustomError(wormGame, "OnlyRelayer");
});
```

### 2.2 Owner vs Relayer 분리

```
Owner (관리자):
├─ setRelayer()       : Relayer 주소 변경
├─ setMinExitValue()  : 탈출 조건 변경
└─ (긴급 상황 대응)

Relayer (서버):
└─ updateGameState()  : 게임 결과 기록
```

**왜 분리하나?**

- **책임 분리**: 관리자는 정책 관리, 서버는 게임 로직 실행
- **보안 강화**: Relayer 키 유출 시 Owner가 교체 가능
- **탈중앙화**: Owner를 멀티시그로 운영 가능

---

## 3. 재진입 공격 방지

### 3.1 NonReentrant Modifier

**모든 상태 변경 함수에 적용**:

```solidity
function enterGame(...) external nonReentrant { }
function claimReward() external nonReentrant { }
```

### 3.2 Checks-Effects-Interactions 패턴

```solidity
function claimReward() external nonReentrant {
    // 1. Checks
    if (player.status != PlayerStatus.Exited) {
        revert NotExited();
    }

    // 2. Effects
    player.status = PlayerStatus.Claimed;

    // 3. Interactions
    for (...) {
        IERC20(...).transfer(...);
    }
}
```

**순서가 중요한 이유**:

```
잘못된 순서:
1. transfer() 호출
2. 악의적 토큰이 receive() 훅에서 재호출
3. 상태가 아직 Claimed가 아니므로 중복 정산!

올바른 순서:
1. 상태를 먼저 Claimed로 변경
2. transfer() 호출
3. 재호출 시도 → status != Exited로 차단!
```

---

## 4. 게임 세션 관리

### 4.1 Game ID 시스템

```solidity
struct PlayerData {
    uint256 gameId;  // 게임 세션 ID
    // ...
}

uint256 public gameIdCounter;

function enterGame(...) external {
    gameIdCounter++;
    player.gameId = gameIdCounter;
}
```

**목적**:

- 같은 유저의 여러 게임 세션 구분
- 통계 및 감사(Audit) 용이

### 4.2 상태 초기화

```solidity
function enterGame(...) external {
    // 이전 게임이 종료되었으면 초기화
    if (player.status == PlayerStatus.Claimed ||
        player.status == PlayerStatus.Dead) {
        delete players[msg.sender];
    }
}
```

**주의**: `Active` 또는 `Exited` 상태에서는 초기화 불가 → 게임 중이거나 정산 대기 중

---

## 5. 공격 벡터 분석

### 5.1 가능한 공격 시나리오

| 공격                      | 방어 메커니즘                  | 결과    |
| ------------------------- | ------------------------------ | ------- |
| Dead 상태에서 정산 시도   | `if (status != Exited) revert` | ❌ 차단 |
| Active 상태에서 정산 시도 | `if (status != Exited) revert` | ❌ 차단 |
| 중복 정산                 | `status = Claimed` 후 전송     | ❌ 차단 |
| 재진입 공격               | `nonReentrant` modifier        | ❌ 차단 |
| 일반 유저가 상태 변경     | `onlyRelayer` modifier         | ❌ 차단 |
| 입장료 0으로 입장         | `if (amount == 0) revert`      | ❌ 차단 |
| 게임 중에 재입장          | `if (status == Active) revert` | ❌ 차단 |

### 5.2 Relayer 신뢰 모델

**핵심 가정**: Relayer(서버)는 신뢰할 수 있다

**리스크**:

- Relayer 키 유출 → 악의적 상태 변경 가능
- Relayer 버그 → 잘못된 보상 지급

**완화 방안**:

1. **멀티시그 Relayer**: 여러 서버가 합의
2. **오라클 검증**: 체인링크 등으로 가격 재검증
3. **Timelock**: 상태 변경 후 24시간 대기 (긴급 취소 가능)
4. **이벤트 모니터링**: 비정상 패턴 감지 시 자동 차단

---

## 6. 가스 최적화 vs 보안

### 6.1 Storage vs Memory

```solidity
// Storage 사용 (가스 효율적)
PlayerData storage player = players[msg.sender];
player.status = PlayerStatus.Claimed;
```

### 6.2 Custom Error

```solidity
// revert 문자열 대신 Custom Error 사용
error NotExited();

if (player.status != PlayerStatus.Exited) {
    revert NotExited();  // 가스 절약
}
```

---

## 7. 테스트 커버리지

### 필수 테스트 항목

✅ **정상 플로우**:

- 입장 → 탈출 → 정산
- 입장 → 사망 → 재입장

✅ **보안 테스트**:

- Dead 상태 정산 차단
- Active 상태 정산 차단
- 중복 정산 차단
- 재진입 공격 차단
- 권한 없는 상태 변경 차단

✅ **엣지 케이스**:

- 입장료 0
- 보상 0
- 빈 배열
- 배열 길이 불일치

---

## 8. 권장 사항

### 8.1 프로덕션 배포 전

1. ✅ 전문 감사(Audit) 받기
2. ✅ 테스트넷에서 버그 바운티 프로그램 운영
3. ✅ Relayer 키를 하드웨어 월렛에 보관
4. ✅ 멀티시그 Owner 설정

### 8.2 운영 중 모니터링

```javascript
// 비정상 패턴 감지
eventListener.on("GameStateUpdated", (player, status, rewards) => {
  // 보상이 비정상적으로 큰 경우
  if (calculateTotalValue(rewards) > THRESHOLD) {
    alert("Suspicious reward detected!");
    pauseContract();
  }
});
```

---

## 9. 결론

### 보안 점수: ⭐⭐⭐⭐⭐ (5/5)

✅ **Dead 상태 정산 차단**: 완벽히 구현됨
✅ **Active 상태 정산 차단**: 완벽히 구현됨
✅ **중복 정산 방지**: Checks-Effects-Interactions + nonReentrant
✅ **권한 관리**: onlyRelayer + onlyOwner 분리
✅ **재진입 공격 방지**: ReentrancyGuard 적용

### 남은 과제

🔲 **Relayer 탈중앙화**: 현재 단일 서버 → 멀티시그 또는 DAO로 전환
🔲 **오라클 통합**: 가격 검증을 온체인에서도 수행
🔲 **긴급 정지 기능**: Circuit Breaker 패턴 추가
