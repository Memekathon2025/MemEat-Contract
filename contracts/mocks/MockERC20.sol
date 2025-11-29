// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    // 생성자: 이름과 심볼을 받아서 만듦 (예: "Fake Bitcoin", "FBTC")
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 배포한 사람한테 100만 개를 공짜로 줌
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    // 필요하면 더 찍어낼 수 있는 함수 (테스트용)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}