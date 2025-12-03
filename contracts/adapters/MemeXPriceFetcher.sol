// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceFetcher.sol";

/**
 * @title MemeXPriceFetcher
 * @notice MemeX 중앙 Bonding Curve에서 모든 MRC-20 토큰의 가격을 조회하는 컨트랙트
 * @dev 모든 MRC-20 토큰 거래는 하나의 중앙 컨트랙트(0x6a59...)를 거침
 *      이 컨트랙트는 각 토큰 주소를 파라미터로 받아 해당 토큰의 가격을 반환함
 *      Bonding Curve 주소: 0x6a594a2C401Cf32D29823Ec10D651819DDfd688D
 */
contract MemeXPriceFetcher is IPriceFetcher {

    // ============ State Variables ============

    /// @notice MemeX 중앙 Bonding Curve 컨트랙트 주소 (모든 MRC-20 토큰 거래를 처리)
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
     * @notice MRC-20 토큰의 현재 M 환산 가격을 조회
     * @param token 조회할 MRC-20 토큰 주소
     * @return price 토큰의 M 환산 가격 (18 decimals 기준)
     * @dev 여러 가격 조회 메서드를 시도하여 가격을 가져옵니다
     *      우선순위: 토큰 주소를 받는 메서드 → 토큰 주소 없는 메서드 (fallback)
     */
    function getPrice(address token) external view override returns (uint256) {
        // 1. getCurrentPrice(address token) 시도
        try this._tryGetCurrentPriceWithToken(token) returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 2. getBuyPrice(address token, uint256 amount) 시도 (1 token 기준)
        try this._tryGetBuyPriceWithToken(token) returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 3. getPrice(address token) 시도
        try this._tryGetPriceWithToken(token) returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 4. Fallback: getCurrentPrice() 시도 (토큰 주소 없음)
        try this._tryGetCurrentPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 5. Fallback: getBuyPrice(uint256) 시도
        try this._tryGetBuyPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 6. Fallback: price() 시도
        try this._tryGetPrice() returns (uint256 price) {
            if (price > 0) return price;
        } catch {}

        // 모든 시도 실패
        revert PriceFetchFailed();
    }

    // ============ Internal Helper Functions ============
    // 토큰 주소를 파라미터로 받는 메서드들

    /**
     * @notice getCurrentPrice(address) 메서드 호출 시도
     */
    function _tryGetCurrentPriceWithToken(address token) external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("getCurrentPrice(address)", token)
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }

    /**
     * @notice getBuyPrice(address, uint256) 메서드 호출 시도
     */
    function _tryGetBuyPriceWithToken(address token) external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("getBuyPrice(address,uint256)", token, 1e18)
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }

    /**
     * @notice getPrice(address) 메서드 호출 시도
     */
    function _tryGetPriceWithToken(address token) external view returns (uint256) {
        (bool success, bytes memory data) = bondingCurve.staticcall(
            abi.encodeWithSignature("getPrice(address)", token)
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        revert PriceFetchFailed();
    }

    // Fallback: 토큰 주소 없이 호출하는 메서드들

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
