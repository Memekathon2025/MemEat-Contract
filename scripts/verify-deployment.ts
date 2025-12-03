import { parseEther, createWalletClient, createPublicClient, http, getContract } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  const contractAddress = "0x12B08668F86A35E9ff9B726FBC46820a7d89335A"; // 배포된 컨트랙트 주소

  console.log(`🔍 Verifying WormGame at ${contractAddress}...`);

  // 1. 지갑 연결
  const privateKey = process.env.INSECTARIUM_PRIVATE_KEY!;
  const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  const account = privateKeyToAccount(formattedPrivateKey as `0x${string}`);

  const chain = {
    id: 43522,
    name: 'Insectarium',
    nativeCurrency: { name: 'M', symbol: 'M', decimals: 18 },
    rpcUrls: {
      default: { http: ['https://rpc.insectarium.memecore.net'] },
      public: { http: ['https://rpc.insectarium.memecore.net'] },
    },
  } as const;

  const walletClient = createWalletClient({
    account,
    chain,
    transport: http('https://rpc.insectarium.memecore.net'),
  });

  const publicClient = createPublicClient({
    chain,
    transport: http('https://rpc.insectarium.memecore.net'),
  });

  console.log(`👤 User Address: ${account.address}`);
  const balance = await publicClient.getBalance({ address: account.address });
  console.log(`💰 User Balance: ${balance.toString()} wei`);

  // 2. 컨트랙트 ABI 로드
  const artifactPath = path.join(__dirname, "../artifacts/contracts/WormGame.sol/WormGame.json");
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));

  // 3. 컨트랙트 인스턴스 생성
  const wormGame = getContract({
    address: contractAddress as `0x${string}`,
    abi: artifact.abi,
    client: { public: publicClient, wallet: walletClient },
  });

  // 4. 게임 입장 (Native M)
  const entryFee = parseEther("0.01"); // 0.01 M
  console.log(`\n🎮 Entering game with ${entryFee.toString()} wei (0.01 M)...`);

  try {
    const hash = await wormGame.write.enterGame(
      ["0x0000000000000000000000000000000000000000", entryFee],
      {
        value: entryFee,
        account,
      }
    );
    console.log(`✅ Transaction sent! Hash: ${hash}`);

    console.log("⏳ Waiting for confirmation...");
    await publicClient.waitForTransactionReceipt({ hash });
    console.log("🎉 Transaction confirmed!");

    // 5. 상태 확인
    const status = await wormGame.read.getPlayerStatus([account.address]);
    console.log(`\n📊 Player Status: ${status} (1 = Active)`);

    if (status === 1) {
      console.log("✨ SUCCESS: Player successfully entered the game!");
    } else {
      console.error("❌ FAILURE: Player status is not Active.");
    }

  } catch (error) {
    console.error("\n❌ Error during execution:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
