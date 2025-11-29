// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 실제 가격을 가져오는 외부 오라클(예: Uniswap, Chainlink) 인터페이스
// WormGame <-> IOracleAdapter (통역사) <-> IPriceFetcher (외국인)
interface IPriceFetcher {
    function getPrice(address token) external view returns (uint256);
}