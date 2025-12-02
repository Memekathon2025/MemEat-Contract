// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title WormGame
 * @notice 상태 머신(State Machine) 기반 게임 컨트랙트
 * @dev Relayer 패턴을 사용하여 오프체인 게임 로직 검증 후 온체인 상태 업데이트
 */
contract WormGame is Ownable, ReentrancyGuard {

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

    // ============ 상태 변수 ============

    // Relayer 주소 (서버)
    address public relayer;

    // 최소 탈출 가치 (USD 기준, 18 decimals)
    uint256 public minExitValue;

    // 플레이어 데이터
    mapping(address => PlayerData) public players;

    // 게임 세션 카운터
    uint256 public gameIdCounter;

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

    // ============ Modifier ============

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert OnlyRelayer();
        _;
    }

    // ============ Constructor ============

    constructor(address _relayer, uint256 _minExitValue) Ownable(msg.sender) {
        relayer = _relayer;
        minExitValue = _minExitValue;
    }

    // ============ 유저 함수 ============

    /**
     * @notice 게임 입장 (입장료 지불)
     * @param token 입장료로 낼 토큰 주소
     * @param amount 입장료 수량
     */
    function enterGame(address token, uint256 amount) external nonReentrant {
        PlayerData storage player = players[msg.sender];

        // 검증: 금액이 0보다 커야 함
        if (amount == 0) revert InvalidAmount();

        // 검증: 이미 게임 중이 아니어야 함
        if (player.status == PlayerStatus.Active) {
            revert AlreadyInGame();
        }

        // 이전 게임 세션이 있었다면 초기화
        if (player.status == PlayerStatus.Claimed ||
            player.status == PlayerStatus.Dead) {
            delete players[msg.sender];
            player = players[msg.sender];
        }

        // 입장료 토큰 전송
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // 게임 ID 증가
        gameIdCounter++;

        // 플레이어 데이터 설정
        player.status = PlayerStatus.Active;
        player.entryToken = token;
        player.entryAmount = amount;
        player.enteredAt = block.timestamp;
        player.gameId = gameIdCounter;

        // 보상 배열 초기화
        delete player.rewardTokens;
        delete player.rewardAmounts;

        emit GameEntered(msg.sender, token, amount, gameIdCounter, block.timestamp);
    }

    /**
     * @notice 보상 정산 (탈출 성공한 유저만 가능)
     * @dev Checks-Effects-Interactions 패턴 적용
     */
    function claimReward() external nonReentrant {
        PlayerData storage player = players[msg.sender];

        // 검증: Exited 상태여야 함
        if (player.status != PlayerStatus.Exited) {
            revert NotExited();
        }

        // 검증: 보상이 있어야 함
        if (player.rewardTokens.length == 0) {
            revert NoRewardToClaim();
        }

        // 상태 변경 (재진입 공격 방지)
        player.status = PlayerStatus.Claimed;

        // 보상 전송
        for (uint256 i = 0; i < player.rewardTokens.length; i++) {
            if (player.rewardAmounts[i] > 0) {
                IERC20(player.rewardTokens[i]).transfer(
                    msg.sender,
                    player.rewardAmounts[i]
                );
            }
        }

        emit RewardClaimed(
            msg.sender,
            player.gameId,
            player.rewardTokens,
            player.rewardAmounts
        );
    }

    // ============ Relayer 함수 ============

    /**
     * @notice 게임 상태 업데이트 (Relayer만 호출 가능)
     * @param player 플레이어 주소
     * @param newStatus 새로운 상태 (Exited 또는 Dead)
     * @param rewardTokens 획득한 토큰 주소 배열
     * @param rewardAmounts 획득한 토큰 수량 배열
     */
    function updateGameState(
        address player,
        PlayerStatus newStatus,
        address[] calldata rewardTokens,
        uint256[] calldata rewardAmounts
    ) external onlyRelayer {
        PlayerData storage playerData = players[player];

        // 검증: Active 상태여야만 업데이트 가능
        if (playerData.status != PlayerStatus.Active) {
            revert InvalidStatus();
        }

        // 검증: Exited 또는 Dead만 가능
        if (newStatus != PlayerStatus.Exited && newStatus != PlayerStatus.Dead) {
            revert InvalidStatus();
        }

        // 검증: 배열 길이 일치
        if (rewardTokens.length != rewardAmounts.length) {
            revert LengthMismatch();
        }

        // 상태 변경
        playerData.status = newStatus;

        // 보상 정보 저장 (Exited일 경우만 의미 있음)
        if (newStatus == PlayerStatus.Exited) {
            playerData.rewardTokens = rewardTokens;
            playerData.rewardAmounts = rewardAmounts;
        } else {
            // Dead 상태면 보상 0
            delete playerData.rewardTokens;
            delete playerData.rewardAmounts;
        }

        emit GameStateUpdated(
            player,
            newStatus,
            playerData.gameId,
            playerData.rewardTokens,
            playerData.rewardAmounts
        );
    }

    // ============ 관리자 함수 ============

    /**
     * @notice Relayer 주소 변경
     */
    function setRelayer(address newRelayer) external onlyOwner {
        address oldRelayer = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(oldRelayer, newRelayer);
    }

    /**
     * @notice 최소 탈출 가치 변경
     */
    function setMinExitValue(uint256 newMinExitValue) external onlyOwner {
        minExitValue = newMinExitValue;
    }

    // ============ View 함수 ============

    /**
     * @notice 플레이어 상태 조회
     */
    function getPlayerStatus(address player) external view returns (PlayerStatus) {
        return players[player].status;
    }

    /**
     * @notice 플레이어 보상 정보 조회
     */
    function getPlayerReward(address player)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        PlayerData storage playerData = players[player];
        return (playerData.rewardTokens, playerData.rewardAmounts);
    }

    /**
     * @notice 컨트랙트 토큰 잔액 조회
     */
    function getContractBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
