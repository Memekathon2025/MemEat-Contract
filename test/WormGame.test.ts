import { describe, it } from "node:test";
import { expect } from "chai";
import { network } from "hardhat";
import { parseEther, keccak256, encodePacked, toBytes } from "viem";

describe("WormGame System", function () {
  async function deployFixture() {
    // 1. 지갑 준비
    const { viem } = await network.connect();
    const [owner, serverSigner, user1] = await viem.getWalletClients();
    const publicClient = await viem.getPublicClient();

    // 2. Mock 컨트랙트 배포
    const mockToken = await viem.deployContract("MockERC20", ["Fake Bitcoin", "FBTC"]);
    const mockPriceFetcher = await viem.deployContract("MockPriceFetcher", []);

    // 3. 오라클 어댑터 배포
    const oracleAdapter = await viem.deployContract("UserOnChainPriceOracleAdapter", [
      mockPriceFetcher.address,
    ]);

    // 4. 게임 컨트랙트 배포
    const wormGame = await viem.deployContract("WormGame", [
      oracleAdapter.address,
      serverSigner.account.address,
    ]);

    // 5. 초기 설정
    await mockToken.write.mint([user1.account.address, parseEther("100")]);
    await mockPriceFetcher.write.setPrice([mockToken.address, parseEther("10")]);
    await wormGame.write.setMinExitValue([parseEther("50")]);

    return {
      wormGame,
      oracleAdapter,
      mockToken,
      mockPriceFetcher,
      owner,
      serverSigner,
      user1,
      publicClient,
    };
  }

  describe("Game Flow", function () {
    it("Should allow entry and exit with rewards", async function () {
      const { wormGame, mockToken, user1, serverSigner } = await deployFixture();

      // --- 1. 입장 (Entry) ---
      const entryFee = parseEther("10");

      const { viem } = await network.connect();
      const mockTokenAsUser1 = await viem.getContractAt("MockERC20", mockToken.address, { client: { wallet: user1 } });
      await mockTokenAsUser1.write.approve([wormGame.address, entryFee]);

      const wormGameAsUser1 = await viem.getContractAt("WormGame", wormGame.address, { client: { wallet: user1 } });
      await wormGameAsUser1.write.enterGame([mockToken.address, entryFee]);

      const balanceAfterEntry = await mockToken.read.balanceOf([user1.account.address]);
      expect(balanceAfterEntry).to.equal(parseEther("90"));

      // --- 2. 게임 플레이 (Off-chain) ---
      const collectedAmount = parseEther("20");
      const nonce = 1n;

      // --- 3. 탈출 (Exit) ---
      const messageHash = keccak256(
        encodePacked(
          ["address", "address[]", "uint256[]", "uint256"],
          [
            user1.account.address,
            [mockToken.address],
            [collectedAmount],
            nonce
          ]
        )
      );
      
      const signature = await serverSigner.signMessage({
        message: { raw: toBytes(messageHash) },
      });

      const gameResult = {
        tokens: [mockToken.address],
        amounts: [collectedAmount],
        nonce: nonce,
      };

      await mockToken.write.mint([wormGame.address, parseEther("1000")]);

      await wormGameAsUser1.write.exitGame([gameResult, signature]);

      // --- 4. 결과 확인 ---
      const finalBalance = await mockToken.read.balanceOf([user1.account.address]);
      expect(finalBalance).to.equal(parseEther("110"));
    });

    it("Should handle death scenario - lose entry fee and collected tokens stay in contract", async function () {
      const { wormGame, mockToken, user1, serverSigner } = await deployFixture();

      // --- 1. 입장 (Entry) ---
      const entryFee = parseEther("10");

      const { viem } = await network.connect();
      const mockTokenAsUser1 = await viem.getContractAt("MockERC20", mockToken.address, { client: { wallet: user1 } });
      await mockTokenAsUser1.write.approve([wormGame.address, entryFee]);

      const wormGameAsUser1 = await viem.getContractAt("WormGame", wormGame.address, { client: { wallet: user1 } });
      await wormGameAsUser1.write.enterGame([mockToken.address, entryFee]);

      const balanceAfterEntry = await mockToken.read.balanceOf([user1.account.address]);
      expect(balanceAfterEntry).to.equal(parseEther("90"));

      // --- 2. 게임 플레이 (Off-chain) - 일부 토큰 수집 ---
      const collectedAmount = parseEther("5"); // minExitValue(50)보다 적은 양
      const nonce = 2n;

      // --- 3. 사망 (Game Over) ---
      const messageHash = keccak256(
        encodePacked(
          ["address", "address[]", "uint256[]", "uint256"],
          [
            user1.account.address,
            [mockToken.address],
            [collectedAmount],
            nonce
          ]
        )
      );
      
      const signature = await serverSigner.signMessage({
        message: { raw: toBytes(messageHash) },
      });

      const gameResult = {
        tokens: [mockToken.address],
        amounts: [collectedAmount],
        nonce: nonce,
      };

      // 수집한 토큰을 컨트랙트에 미리 준비 (맵에서 수집한 토큰)
      await mockToken.write.mint([wormGame.address, collectedAmount]);

      // 사망 처리
      await wormGameAsUser1.write.gameOver([gameResult, signature]);

      // --- 4. 결과 확인 ---
      // 입장료(10)는 잃고, 수집한 토큰(5)도 정산되지 않음
      // 최종 잔액: 100 - 10(입장료) = 90
      const finalBalance = await mockToken.read.balanceOf([user1.account.address]);
      expect(finalBalance).to.equal(parseEther("90"));

      // 수집한 토큰은 컨트랙트에 남아있음
      const contractBalance = await mockToken.read.balanceOf([wormGame.address]);
      expect(contractBalance).to.equal(parseEther("15")); // 입장료(10) + 수집한 토큰(5)

      // Nonce 재사용 방지 확인
      const usedNonce = await wormGame.read.usedNonces([nonce]);
      expect(usedNonce).to.be.true;
    });
  });
});
