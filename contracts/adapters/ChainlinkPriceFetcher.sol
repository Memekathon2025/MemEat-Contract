// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceFetcher.sol";

// Chainlink 인터페이스
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

/**
 * @title ChainlinkPriceFetcher
 * @notice Chainlink 오라클에서 실제 가격을 가져오는 프로덕션용 컨트랙트
 * @dev 각 토큰마다 Chainlink Price Feed 주소를 등록해야 합니다
 */
contract ChainlinkPriceFetcher is IPriceFetcher {
    // 관리자
    address public owner;

    // 토큰 주소 -> Chainlink Price Feed 주소 매핑
    mapping(address => address) public priceFeeds;

    event PriceFeedUpdated(address indexed token, address indexed priceFeed);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice 특정 토큰의 Price Feed 주소 설정
     * @param token 토큰 주소
     * @param priceFeed Chainlink Price Feed 주소
     */
    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(priceFeed != address(0), "Invalid price feed");
        priceFeeds[token] = priceFeed;
        emit PriceFeedUpdated(token, priceFeed);
    }

    /**
     * @notice 토큰의 USD 가격 조회 (18 decimals)
     * @param token 토큰 주소
     * @return price USD 가격 (18 decimals)
     */
    function getPrice(address token) external view override returns (uint256) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "Price feed not set");

        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        (, int256 price, , , ) = feed.latestRoundData();
        require(price > 0, "Invalid price");

        // Chainlink 가격을 18 decimals로 변환
        uint8 decimals = feed.decimals();
        if (decimals < 18) {
            return uint256(price) * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            return uint256(price) / (10 ** (decimals - 18));
        }
        return uint256(price);
    }
}
