// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IWormGame.sol";
import "./interfaces/IPriceFetcher.sol";

contract UserOnChainPriceOracleAdapter is IOracleAdapter {
    // 진짜 오라클의 주소를 저장
    IPriceFetcher public priceFetcher;

    constructor(address _priceFetcher) {
        priceFetcher = IPriceFetcher(_priceFetcher);
    }

    // 개별 토큰 가격 조회 (외부에서 확인용)
    function getPrice(address token) external view returns (uint256) {
        return priceFetcher.getPrice(token);
    }

    // 여러 토큰의 총 가치 합산 (WormGame에서 호출)
    // override 키워드: "인터페이스에 있는 약속을 내가 구현했다"는 뜻
    function getTotalValue(address[] calldata tokens, uint256[] calldata amounts) external view override returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 price = priceFetcher.getPrice(tokens[i]);
            
            // 단순화된 계산식: (수량 * 가격) / 1e18
            // 주의: 실제로는 토큰마다 소수점(Decimals)이 달라서 더 정교한 계산이 필요할 수 있습니다.
            // 여기서는 모든 토큰과 가격이 18자리 소수점을 쓴다고 가정합니다.
            totalValue += (amounts[i] * price) / 1e18; 
        }
        return totalValue;
    }
}