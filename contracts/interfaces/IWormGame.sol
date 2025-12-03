// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWormGame
 * @notice WormGame 컨트랙트의 인터페이스 및 공통 정의
 */
interface IWormGame {
    
    // ============ 상태 정의 (State Machine) ============

    enum PlayerStatus {
        NotStarted, // 0: 게임 시작 전 (기본값)
        Active,     // 1: 게임 중 (생존)
        Exited,     // 2: 탈출 성공 (정산 대기)
        Dead,       // 3: 사망 (정산 불가)
        Claimed     // 4: 정산 완료
    }

    // ============ 구조체 정의 ============

    struct PlayerData {
        PlayerStatus status;           // 현재 상태
        address entryToken;            // 입장료로 낸 토큰 주소
        uint256 entryAmount;           // 입장료 수량
        address[] rewardTokens;        // 획득한 토큰 종류
        uint256[] rewardAmounts;       // 획득한 토큰 수량
        uint256 enteredAt;             // 입장 시간
        uint256 gameId;                // 게임 세션 ID (재진입 구분용)
    }

    // ============ 이벤트 ============

    event GameEntered(
        address indexed player,
        address token,
        uint256 amount,
        uint256 gameId,
        uint256 timestamp
    );

    event GameStateUpdated(
        address indexed player,
        PlayerStatus newStatus,
        uint256 gameId,
        address[] rewardTokens,
        uint256[] rewardAmounts
    );

    event RewardClaimed(
        address indexed player,
        uint256 gameId,
        address[] tokens,
        uint256[] amounts
    );

    event RelayerUpdated(
        address indexed oldRelayer,
        address indexed newRelayer
    );

    // ============ 에러 정의 ============

    error OnlyRelayer();
    error InvalidStatus();
    error InvalidAmount();
    error AlreadyInGame();
    error NotExited();
    error NoRewardToClaim();
    error LengthMismatch();
    error InvalidEntry();

    // ============ 함수 정의 ============

    function enterGame(address token, uint256 amount) external payable;
    
    function claimReward() external;
    
    function updateGameState(
        address player,
        PlayerStatus newStatus,
        address[] calldata rewardTokens,
        uint256[] calldata rewardAmounts
    ) external;
    
    function setRelayer(address newRelayer) external;

    function getPlayerStatus(address player) external view returns (PlayerStatus);
    
    function getPlayerReward(address player) external view returns (address[] memory, uint256[] memory);
    
    function getContractBalance(address token) external view returns (uint256);
}

// 오라클 어댑터 인터페이스 (UserOnChainPriceOracleAdapter에서 사용)
interface IOracleAdapter {
    function getTotalValue(address[] calldata tokens, uint256[] calldata amounts) external view returns (uint256);
}