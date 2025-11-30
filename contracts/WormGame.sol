// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/IWormGame.sol"; 

// ReentrancyGuard: 재진입 공격 방지, Ownable: 소유권 관리
contract WormGame is ReentrancyGuard, Ownable, IWormGame {
    using ECDSA for bytes32;
 
    IOracleAdapter public oracleAdapter; // 가격 정보를 가져올 오라클
    address public serverSigner; // 서버의 서명을 검증할 공개키
    
    // 탈출을 위해 필요한 최소 가치 (USD 등 기준 통화 단위)
    uint256 public minExitValue;

    // 이벤트 정의
    event GameEntered(address indexed user, address token, uint256 amount);
    event GameExited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event GameOver(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);

    // 재사용 방지 (Replay Attack 방지)를 위한 Nonce 관리
    mapping(uint256 => bool) public usedNonces;

    constructor(address _oracleAdapter, address _serverSigner) Ownable(msg.sender) {
        oracleAdapter = IOracleAdapter(_oracleAdapter);
        serverSigner = _serverSigner;
    }

    // 설정 변경 함수들 (관리자 전용)
    // 오라클 어댑터 변경
    function setOracleAdapter(address _oracleAdapter) external onlyOwner {
        oracleAdapter = IOracleAdapter(_oracleAdapter);
    }

    // 서버 서명자 변경
    function setServerSigner(address _serverSigner) external onlyOwner {
        serverSigner = _serverSigner;
    }

    // 최소 탈출 가치 변경
    function setMinExitValue(uint256 _value) external onlyOwner {
        minExitValue = _value;
    }

    // 1. 입장 (Entry): 유저가 토큰을 내고 게임에 참가
    function enterGame(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        // 유저의 토큰을 컨트랙트(Vault)로 가져옴
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit GameEntered(msg.sender, token, amount);
    }

    // 2. 탈출 (Exit): 게임 결과에 따라 토큰을 정산받음
    // nonce: 영수증 번호, signature: 서버 도장
    function exitGame(
        GameResult calldata result,
        bytes calldata signature
    ) external nonReentrant {
        if (result.tokens.length != result.amounts.length) revert LengthMismatch();
        if (usedNonces[result.nonce]) revert NonceAlreadyUsed();

        // A. 서버 서명 검증 (유효한 게임 플레이였는지 확인)
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, result.tokens, result.amounts, result.nonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
       if (ethSignedMessageHash.recover(signature) != serverSigner) revert InvalidSignature();

        usedNonces[result.nonce] = true;

        // B. 오라클을 통해 가치 검증 (Total Value 확인)
        uint256 totalValue = oracleAdapter.getTotalValue(result.tokens, result.amounts);
        if (totalValue < minExitValue) revert InsufficientExitValue();

        // C. 토큰 정산 (유저에게 전송)
        for (uint256 i = 0; i < result.tokens.length; i++) {
            if (result.amounts[i] > 0) {
                IERC20(result.tokens[i]).transfer(msg.sender, result.amounts[i]);
            }
        }

        emit GameExited(msg.sender, result.tokens, result.amounts, totalValue);
    }

    // 3. 사망 (Game Over): 플레이어가 사망하여 입장료를 잃고 수집한 토큰은 맵에 다시 뿌려짐
    // nonce: 영수증 번호, signature: 서버 도장
    function gameOver(
        GameResult calldata result,
        bytes calldata signature
    ) external nonReentrant {
        if (result.tokens.length != result.amounts.length) revert LengthMismatch();
        if (usedNonces[result.nonce]) revert NonceAlreadyUsed();

        // A. 서버 서명 검증 (유효한 게임 플레이였는지 확인)
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, result.tokens, result.amounts, result.nonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        if (ethSignedMessageHash.recover(signature) != serverSigner) revert InvalidSignature();

        usedNonces[result.nonce] = true;

        // B. 오라클을 통해 가치 계산 (Total Value 확인, 정산은 하지 않음)
        uint256 totalValue = oracleAdapter.getTotalValue(result.tokens, result.amounts);

        // C. 수집한 토큰은 컨트랙트에 남김 (정산하지 않음, 맵에 다시 뿌려짐)
        // 입장료는 이미 컨트랙트에 있으므로 별도 처리 불필요

        emit GameOver(msg.sender, result.tokens, result.amounts, totalValue);
    }
}