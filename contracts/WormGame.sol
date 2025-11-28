// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// 오라클 어댑터 인터페이스 정의(시세표를 들고 있는 환전소 직원)
interface IOracleAdapter {
    function getTotalValue(address[] calldata tokens, uint256[] calldata amounts) external view returns (uint256);
}

// ReentrancyGuard: 재진입 공격 방지, Ownable: 소유권 관리
contract WormGame is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    IOracleAdapter public oracleAdapter; // 가격 정보를 가져올 오라클
    address public serverSigner;        // 서버의 서명을 검증할 공개키
    
    // 탈출을 위해 필요한 최소 가치 (USD 등 기준 통화 단위)
    uint256 public minExitValue;

    // 이벤트 정의
    // token: 토큰의 종류
    event GameEntered(address indexed user, address token, uint256 amount);
    event GameExited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);

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
        require(amount > 0, "Amount must be > 0");
        
        // 유저의 토큰을 컨트랙트(Vault)로 가져옴
        // 주의: 유저가 미리 approve()를 해둬야 함
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit GameEntered(msg.sender, token, amount);
    }

    // 2. 탈출 (Exit): 게임 결과에 따라 토큰을 정산받음
    // nonce: 영수증 번호, signature: 서버 도장
    function exitGame(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant {
        require(tokens.length == amounts.length, "Length mismatch");
        require(!usedNonces[nonce], "Nonce used");

        // A. 서버 서명 검증 (유효한 게임 플레이였는지 확인)
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, tokens, amounts, nonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        require(ethSignedMessageHash.recover(signature) == serverSigner, "Invalid signature");

        usedNonces[nonce] = true;

        // B. 오라클을 통해 가치 검증 (Total Value 확인)
        uint256 totalValue = oracleAdapter.getTotalValue(tokens, amounts);
        require(totalValue >= minExitValue, "Value too low to exit");

        // C. 토큰 정산 (유저에게 전송)
        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).transfer(msg.sender, amounts[i]);
            }
        }

        emit GameExited(msg.sender, tokens, amounts, totalValue);
    }
}