// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceFetcher.sol";

/**
 * @title MemeXPriceFetcher
 * @notice MemeX Bonding Curve에서 MXT 토큰의 현재 가격을 가져오는 컨트랙트
 * @dev Bonding Curve 주소: 0x6a594a2C401Cf32D29823Ec10D651819DDfd688D
 */
contract MemeXPriceFetcher is IPriceFetcher {

    // ============ State Variables ============

    /// @notice MemeX Bonding Curve 컨트랙트 주소
    address public immutable bondingCurve;

    // ============ Errors ============

    error InvalidBondingCurveAddress();
    error PriceFetchFailed();

    // ============ Constructor ============

    /**
     * @notice MemeXPriceFetcher 생성자
     * @param _bondingCurve Bonding Curve 컨트랙트 주소
     */
    constructor(address _bondingCurve) {
        if (_bondingCurve == address(0)) revert InvalidBondingCurveAddress();
        bondingCurve = _bondingCurve;
    }

    // ============ External Functions ============

    /**
     * @notice MXT 토큰의 현재 가격을 조회
     * @param token 토큰 주소 (사용되지 않음 - Bonding Curve에서 직접 조회)
     * @return price 토큰 가격 (18 decimals 기준)
     * @dev 여러 가격 조회 메서드를 시도하여 가격을 가져옵니다
     */
    function getPrice(address token) external view override returns (uint256) {
        // token 파라미터는 인터페이스 호환성을 위해 존재하지만 사용되지 않음
        token;
        // 1. getCurrentPrice() 시도
        try this._tryGetCurrentPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 2. getBuyPrice() 시도 (1 token 기준)
        try this._tryGetBuyPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 3. price() 시도
        try this._tryGetPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 모든 시도 실패
        revert PriceFetchFailed();
    }

    // ============ Internal Helper Functions ============

    /**
     * @notice getCurrentPrice() 메서드 호출 시도
     */
    function _tryGetCurrentPrice() external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("getCurrentPrice()")
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }

    /**
     * @notice getBuyPrice(uint256) 메서드 호출 시도 (1 token 기준)
     */
    function _tryGetBuyPrice() external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("getBuyPrice(uint256)", 1e18)
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }

    /**
     * @notice price() 메서드 호출 시도
     */
    function _tryGetPrice() external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("price()")
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }
}
