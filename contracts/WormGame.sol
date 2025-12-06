// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IWormGame.sol";

/**
 * @title WormGame
 * @notice 상태 머신(State Machine) 기반 게임 컨트랙트
 * @dev Relayer 패턴을 사용하여 오프체인 게임 로직 검증 후 온체인 상태 업데이트
 *
 * ## 탈출 조건 (Exit Condition)
 * 탈출 조건은 온체인이 아닌 **백엔드(Relayer)에서 검증**됩니다:
 * - 플레이어가 게임에서 획득한 모든 MRC-20 토큰의 **총 M 환산 가치**
 * - 이 값이 플레이어가 입장 시 예치한 **entryAmount** 이상이면 탈출 가능
 * - 백엔드는 각 토큰의 실시간 가격을 조회하여 총 가치를 계산
 * - 탈출 조건 만족 시 Relayer가 updateGameState()를 호출하여 Exited 상태로 변경
 *
 * 예시:
 * - 입장료: 1 M
 * - 획득 토큰: sdf 100개 (0.005 M/개) + z 20개 (0.05 M/개)
 * - 총 가치: (100 * 0.005) + (20 * 0.05) = 0.5 + 1.0 = 1.5 M
 * - 1.5 M >= 1 M → 탈출 가능 ✅
 */
contract WormGame is Ownable, ReentrancyGuard, IWormGame {

    // ============ 상태 변수 ============

    // Relayer 주소 (서버)
    address public relayer;

    // 수수료 받을 지갑 (Treasury)
    address public treasury;

    // 입장료 수수료율 (단위: 1/10000, 500 = 5%)
    uint256 public feeRate = 500;

    // 플레이어 데이터
    mapping(address => PlayerData) public players;

    // 게임 세션 카운터
    uint256 public gameIdCounter;

    // ============ Modifier ============

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert OnlyRelayer();
        _;
    }

    // ============ Constructor ============

    constructor(address _relayer, address _treasury) Ownable(msg.sender) {
        relayer = _relayer;
        treasury = _treasury;
    }

    // ============ 유저 함수 ============

    /**
     * @notice 게임 입장 (입장료 지불)
     * @param token 입장료로 낼 토큰 주소 (Native M인 경우 address(0))
     * @param amount 입장료 수량 (Native M인 경우 msg.value와 일치해야 함)
     */
    function enterGame(address token, uint256 amount) external payable override nonReentrant {
        PlayerData storage player = players[msg.sender];

        // 검증: 게임 중이 아니거나 보상을 받기 전이 아니어야 함
        if (player.status == PlayerStatus.Active || player.status == PlayerStatus.Exited) {
            revert AlreadyInGame();
        }

        // 이전 게임 세션이 있었다면 초기화
        if (player.status == PlayerStatus.Claimed ||
            player.status == PlayerStatus.Dead) {
            delete players[msg.sender];
            player = players[msg.sender];
        }

        // 입장료 처리 로직 (수수료 차감)
        uint256 fee = (amount * feeRate) / 10000;
        uint256 netAmount = amount - fee;

        if (msg.value > 0) {
            // Case 1: Native M 코인으로 입장
            if (token != address(0)) revert InvalidEntry(); // Native 입장 시 token은 0이어야 함
            if (msg.value != amount) revert InvalidAmount(); // 금액 불일치

            // 수수료 전송 (Treasury로)
            (bool success, ) = treasury.call{value: fee}("");
            require(success, "Fee transfer failed");
        } else {
            // Case 2: MRC-20 토큰으로 입장
            if (token == address(0)) revert InvalidEntry(); // 토큰 주소 필수
            if (amount == 0) revert InvalidAmount(); // 0원 입장 불가
            
            // 수수료 전송 (User -> Treasury)
            IERC20(token).transferFrom(msg.sender, treasury, fee);

            // 게임 팟 전송 (User -> Contract)
            IERC20(token).transferFrom(msg.sender, address(this), netAmount);
        }

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
    function claimReward() external override nonReentrant {
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
                if (player.rewardTokens[i] == address(0)) {
                    // 네이티브 토큰 전송
                    (bool success, ) = msg.sender.call{value: player.rewardAmounts[i]}("");
                    require(success, "Native token transfer failed");
                } else {
                    // ERC20 토큰 전송
                    IERC20(player.rewardTokens[i]).transfer(
                        msg.sender,
                        player.rewardAmounts[i]
                    );
                }
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
    ) external override onlyRelayer {
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
    function setRelayer(address newRelayer) external override onlyOwner {
        address oldRelayer = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(oldRelayer, newRelayer);
    }

    /**
     * @notice 수수료율 변경 (Max 10%)
     */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee rate too high");
        feeRate = _feeRate;
    }

    /**
     * @notice Treasury 주소 변경
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid address");
        treasury = _treasury;
    }


    // ============ View 함수 ============

    /**
     * @notice 플레이어 상태 조회
     */
    function getPlayerStatus(address player) external view override returns (PlayerStatus) {
        return players[player].status;
    }

    /**
     * @notice 플레이어 보상 정보 조회
     */
    function getPlayerReward(address player)
        external
        view
        override
        returns (address[] memory, uint256[] memory)
    {
        PlayerData storage playerData = players[player];
        return (playerData.rewardTokens, playerData.rewardAmounts);
    }

    /**
     * @notice 컨트랙트 토큰 잔액 조회
     */
    function getContractBalance(address token) external view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
