// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceFetcher.sol"; // 우리가 만든 규격을 따름

contract MockPriceFetcher is IPriceFetcher {
    // 토큰 주소 -> 가격 저장소
    mapping(address => uint256) public prices;

    // 가격 설정 (테스트할 때 우리가 호출함)
    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    // 가격 조회 (어댑터가 호출함)
    function getPrice(address token) external view override returns (uint256) {
        return prices[token];
    }
}