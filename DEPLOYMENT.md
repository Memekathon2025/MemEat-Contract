# 배포 가이드

## 환경 설정

### 1. 환경 변수 설정

`.env` 파일을 생성하고 다음 내용을 추가:

```bash
# 배포할 지갑의 Private Key
INSECTARIUM_PRIVATE_KEY=your_private_key_here

# 게임 서버 서명자 주소
SERVER_SIGNER_ADDRESS=0x...
```

### 2. 파라미터 파일 생성

#### 테스트넷용 (parameters.json)
```json
{
  "WormGameModule": {
    "serverSigner": "0x..."
  }
}
```

#### 프로덕션용 (parameters-production.json)
```json
{
  "WormGameProductionModule": {
    "serverSigner": "0x..."
  }
}
```

## 배포 방법

### 테스트넷 배포 (MockPriceFetcher 사용)

```bash
npm run deploy:insectarium
```

또는

```bash
npx hardhat ignition deploy ignition/modules/WormGame.ts --network insectarium --parameters parameters.json
```

배포되는 컨트랙트:
- MockPriceFetcher (테스트용 가격 오라클)
- UserOnChainPriceOracleAdapter
- WormGame

### 프로덕션 배포 (Chainlink 오라클 사용)

```bash
npx hardhat ignition deploy ignition/modules/WormGameProduction.ts --network <network-name> --parameters parameters-production.json
```

배포되는 컨트랙트:
- ChainlinkPriceFetcher (실제 가격 오라클)
- UserOnChainPriceOracleAdapter
- WormGame

### 배포 후 설정

#### ChainlinkPriceFetcher 사용 시

각 토큰에 대한 Chainlink Price Feed 주소를 설정해야 합니다:

```typescript
// Chainlink Price Feed 설정 예시
await chainlinkPriceFetcher.write.setPriceFeed([
  "0x...tokenAddress",  // 토큰 주소
  "0x...priceFeedAddress"  // Chainlink Price Feed 주소
]);
```

주요 체인별 Chainlink Price Feed:
- Ethereum: https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum
- Arbitrum: https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum
- Optimism: https://docs.chain.link/data-feeds/price-feeds/addresses?network=optimism

## 배포된 주소 확인

배포 후 생성된 파일 확인:
```bash
cat ignition/deployments/chain-<chainId>/deployed_addresses.json
```

## 테스트

```bash
npm test
```

## 스크립트 실행

### 배포된 컨트랙트 상호작용

```bash
npm run interact
```

또는

```bash
npx hardhat run scripts/interact-contract.ts --network insectarium
```

## 현재 배포 상태 (Insectarium Testnet)

| 컨트랙트 | 주소 |
|---------|------|
| MockPriceFetcher | `0x9368cA91aA343561beA8d88BC7336ca2E95c6e69` |
| UserOnChainPriceOracleAdapter | `0x50437b0960d719313Eeea64f370219103D7a6070` |
| WormGame | `0x81CD91E8255bb8926746Aa630185F80F2f8A3a84` |

네트워크: Insectarium Testnet (Chain ID: 43522)
RPC URL: https://rpc.insectarium.memecore.net
