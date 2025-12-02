import { describe, it } from "node:test";
import { expect, use } from "chai";
import chaiAsPromised from "chai-as-promised";
import { network } from "hardhat";
import { parseEther } from "viem";

use(chaiAsPromised);

describe("WormGame (State Machine)", function () {
  // 상태 enum (Solidity와 동일)
  const PlayerStatus = {
    NotStarted: 0,
    Active: 1,
    Exited: 2,
    Dead: 3,
    Claimed: 4,
  };

  async function deployFixture() {
    const { viem } = await network.connect();
    const [owner, relayer, player1, player2] = await viem.getWalletClients();
    const publicClient = await viem.getPublicClient();

    // Mock ERC20 토큰 배포
    const mockToken = await viem.deployContract("MockERC20", [
      "Test Token",
      "TEST",
    ]);

    // WormGame 배포
    const wormGame = await viem.deployContract("WormGame", [
      relayer.account.address,
      parseEther("1000"), // targetMemeAmount = 1000 Tokens
    ]);

    // 플레이어에게 토큰 발행
    await mockToken.write.mint([player1.account.address, parseEther("1000")]);
    await mockToken.write.mint([player2.account.address, parseEther("1000")]);

    return {
      wormGame,
      mockToken,
      owner,
      relayer,
      player1,
      player2,
      publicClient,
    };
  }

  describe("🎮 Entry Flow (입장)", function () {
    it("Should allow player to enter game", async function () {
      const { wormGame, mockToken, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");

      // 1. Approve
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      // 2. Enter Game
      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 3. 상태 확인
      const status = await wormGame.read.getPlayerStatus([
        player1.account.address,
      ]);
      expect(status).to.equal(PlayerStatus.Active);

      // 4. 잔액 확인
      const balance = await mockToken.read.balanceOf([player1.account.address]);
      expect(balance).to.equal(parseEther("990"));
    });

    it("Should prevent entering with 0 amount", async function () {
      const { wormGame, mockToken, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );

      await expect(
        wormGameAsPlayer1.write.enterGame([mockToken.address, 0n])
      ).to.be.rejected;
    });

    it("Should prevent entering while already active", async function () {
      const { wormGame, mockToken, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");

      // 첫 번째 입장
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, parseEther("100")]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 두 번째 입장 시도 → 실패
      await expect(
        wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee])
      ).to.be.rejected;
    });
  });

  describe("🎯 Exit Flow (탈출)", function () {
    it("Should allow Relayer to mark player as Exited", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      // 1. 입장
      const entryFee = parseEther("10");
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. Relayer가 탈출 처리
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );

      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Exited,
        [mockToken.address],
        [parseEther("100")],
      ]);

      // 3. 상태 확인
      const status = await wormGame.read.getPlayerStatus([
        player1.account.address,
      ]);
      expect(status).to.equal(PlayerStatus.Exited);
    });

    it("Should prevent non-Relayer from updating state", async function () {
      const { wormGame, mockToken, player1, player2 } = await deployFixture();
      const { viem } = await network.connect();

      // 1. 입장
      const entryFee = parseEther("10");
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. 일반 유저가 상태 변경 시도 → 실패
      const wormGameAsPlayer2 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player2 } }
      );

      await expect(
        wormGameAsPlayer2.write.updateGameState([
          player1.account.address,
          PlayerStatus.Exited,
          [mockToken.address],
          [parseEther("1000")],
        ])
      ).to.be.rejected;
    });
  });

  describe("💰 Claim Flow (정산)", function () {
    it("Should allow Exited player to claim rewards", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");
      const rewardAmount = parseEther("100");

      // 1. 입장
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. 컨트랙트에 보상 토큰 준비
      await mockToken.write.mint([wormGame.address, rewardAmount]);

      // 3. Relayer가 탈출 처리
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );
      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Exited,
        [mockToken.address],
        [rewardAmount],
      ]);

      // 4. 정산
      await wormGameAsPlayer1.write.claimReward();

      // 5. 상태 확인
      const status = await wormGame.read.getPlayerStatus([
        player1.account.address,
      ]);
      expect(status).to.equal(PlayerStatus.Claimed);

      // 6. 잔액 확인
      const balance = await mockToken.read.balanceOf([player1.account.address]);
      expect(balance).to.equal(parseEther("1090")); // 1000 - 10 + 100
    });

    it("Should prevent Active player from claiming", async function () {
      const { wormGame, mockToken, player1 } = await deployFixture();
      const { viem } = await network.connect();

      // 1. 입장 (Active 상태)
      const entryFee = parseEther("10");
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. 정산 시도 → 실패
      await expect(
        wormGameAsPlayer1.write.claimReward()
      ).to.be.rejected;
    });

    it("Should prevent Dead player from claiming", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      // 1. 입장
      const entryFee = parseEther("10");
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. Relayer가 사망 처리
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );
      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Dead,
        [],
        [],
      ]);

      // 3. 정산 시도 → 실패
      await expect(
        wormGameAsPlayer1.write.claimReward()
      ).to.be.rejected;
    });

    it("Should prevent double claiming", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");
      const rewardAmount = parseEther("100");

      // 1. 입장
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. 보상 준비
      await mockToken.write.mint([wormGame.address, rewardAmount]);

      // 3. 탈출 처리
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );
      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Exited,
        [mockToken.address],
        [rewardAmount],
      ]);

      // 4. 첫 번째 정산 → 성공
      await wormGameAsPlayer1.write.claimReward();

      // 5. 두 번째 정산 시도 → 실패
      await expect(
        wormGameAsPlayer1.write.claimReward()
      ).to.be.rejected;
    });
  });

  describe("☠️ Death Flow (사망)", function () {
    it("Should handle player death correctly", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");

      // 1. 입장
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, entryFee]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. Relayer가 사망 처리
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );
      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Dead,
        [],
        [],
      ]);

      // 3. 상태 확인
      const status = await wormGame.read.getPlayerStatus([
        player1.account.address,
      ]);
      expect(status).to.equal(PlayerStatus.Dead);

      // 4. 보상 확인 (없어야 함)
      const [tokens, amounts] = await wormGame.read.getPlayerReward([
        player1.account.address,
      ]);
      expect(tokens.length).to.equal(0);
      expect(amounts.length).to.equal(0);
    });

    it("Should allow re-entry after death", async function () {
      const { wormGame, mockToken, relayer, player1 } = await deployFixture();
      const { viem } = await network.connect();

      const entryFee = parseEther("10");

      // 1. 첫 번째 게임 - 입장
      const mockTokenAsPlayer1 = await viem.getContractAt(
        "MockERC20",
        mockToken.address,
        { client: { wallet: player1 } }
      );
      await mockTokenAsPlayer1.write.approve([wormGame.address, parseEther("100")]);

      const wormGameAsPlayer1 = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: player1 } }
      );
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 2. 사망
      const wormGameAsRelayer = await viem.getContractAt(
        "WormGame",
        wormGame.address,
        { client: { wallet: relayer } }
      );
      await wormGameAsRelayer.write.updateGameState([
        player1.account.address,
        PlayerStatus.Dead,
        [],
        [],
      ]);

      // 3. 두 번째 게임 - 재입장 (성공해야 함)
      await wormGameAsPlayer1.write.enterGame([mockToken.address, entryFee]);

      // 4. 상태 확인
      const status = await wormGame.read.getPlayerStatus([
        player1.account.address,
      ]);
      expect(status).to.equal(PlayerStatus.Active);
    });
  });

  describe("🔧 Admin Functions (관리자)", function () {
    it("Should allow owner to change Relayer", async function () {
      const { wormGame, player1 } = await deployFixture();

      await wormGame.write.setRelayer([player1.account.address]);

      const newRelayer = await wormGame.read.relayer();
      expect(newRelayer.toLowerCase()).to.equal(
        player1.account.address.toLowerCase()
      );
    });

    it("Should allow owner to change exit criteria", async function () {
      const { wormGame } = await deployFixture();

      const newTargetAmount = parseEther("2000");
      await wormGame.write.setExitCriteria([newTargetAmount]);

      const targetAmount = await wormGame.read.targetMemeAmount();
      
      expect(targetAmount).to.equal(newTargetAmount);
    });
  });
});
