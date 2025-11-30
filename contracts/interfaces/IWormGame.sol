// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 구조체 정의
struct GameResult {
    address[] tokens;
    uint256[] amounts;
    uint256 nonce;
}

// 오라클 어댑터 인터페이스
// WormGame <-> IOracleAdapter (통역사) <-> IPriceFetcher (외국인)
interface IOracleAdapter {
    function getTotalValue(address[] calldata tokens, uint256[] calldata amounts) external view returns (uint256);
}

// WormGame 인터페이스 (선택 사항이지만 추천)
interface IWormGame {
    // 에러 정의
    error InvalidAmount();              // 금액이 0일 때
    error LengthMismatch();             // 토큰과 수량 배열 길이가 다를 때
    error NonceAlreadyUsed();           // 이미 사용된 서명일 때
    error InvalidSignature();           // 서명이 위조되었을 때
    error InsufficientExitValue();      // 획득한 가치가 최소 기준보다 낮을 때
    
    function enterGame(address token, uint256 amount) external;
    function exitGame(GameResult calldata result, bytes calldata signature) external;
    function gameOver(GameResult calldata result, bytes calldata signature) external;
}