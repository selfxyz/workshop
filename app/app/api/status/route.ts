import { NextResponse } from "next/server";
import { ethers } from "ethers";

export const dynamic = "force-dynamic";

export async function GET() {
  // Always return 200 with best-effort data to avoid client error overlays / QR reloads
  const srcAddr = process.env.NEXT_PUBLIC_SOURCE_CONTRACT as string | undefined;
  const dstAddr = process.env.NEXT_PUBLIC_DEST_CONTRACT as string | undefined;
  const srcRpc = process.env.SOURCE_RPC as string | undefined;
  const dstRpc = process.env.DEST_RPC as string | undefined;

  if (!srcAddr || !dstAddr || !srcRpc || !dstRpc) {
    return NextResponse.json({ src: [], dst: [], warnings: ["Missing env: SOURCE/DEST RPC or addresses"] });
  }

  const srcProvider = new ethers.JsonRpcProvider(srcRpc);
  const dstProvider = new ethers.JsonRpcProvider(dstRpc);

  const srcIface = new ethers.Interface([
    "event VerificationSentCrossChain(uint32 indexed dstEid, address indexed userAddress, bytes32 indexed verificationConfigId, (address userAddress, bytes32 verificationConfigId, uint256 timestamp, string gender, string nationality, uint256 minimumAge) data)"
  ]);
  const dstIface = new ethers.Interface([
    "event VerificationReceived(uint32 indexed srcEid, address indexed userAddress, bytes32 indexed verificationConfigId, uint256 timestamp)"
  ]);

  const result = { src: [] as any[], dst: [] as any[], warnings: [] as string[] };

  try {
    const currentSrc = await srcProvider.getBlockNumber();
    const fromSrc = Math.max(currentSrc - 8000, 1); // Reasonable search range
    const srcTopic0 = srcIface.getEvent("VerificationSentCrossChain").topicHash;
    const srcLogs = await srcProvider.getLogs({ address: srcAddr, fromBlock: fromSrc, toBlock: currentSrc, topics: [srcTopic0] });

    result.src = srcLogs.slice(-10).reverse().map((l) => { // Show more results
      try {
        const p = srcIface.parseLog(l);
        return {
          txHash: l.transactionHash,
          blockNumber: l.blockNumber,
          user: p.args.userAddress as string,
          dstEid: Number(p.args.dstEid),
          configId: p.args.verificationConfigId as string,
        };
      } catch (parseErr: any) {
        result.warnings.push(`Failed to parse source log: ${parseErr?.message ?? String(parseErr)}`);
        return null;
      }
    }).filter(Boolean) as any[];
  } catch (e: any) {
    result.warnings.push(`Source fetch failed: ${e?.message ?? String(e)}`);
  }

  try {
    const currentDst = await dstProvider.getBlockNumber();
    const fromDst = Math.max(currentDst - 8000, 1); // Reasonable search range
    const dstTopic0 = dstIface.getEvent("VerificationReceived").topicHash;
    const dstLogs = await dstProvider.getLogs({ address: dstAddr, fromBlock: fromDst, toBlock: currentDst, topics: [dstTopic0] });

    result.dst = dstLogs.slice(-10).reverse().map((l) => { // Show more results
      try {
        const p = dstIface.parseLog(l);
        return {
          txHash: l.transactionHash,
          blockNumber: l.blockNumber,
          user: p.args.userAddress as string,
          srcEid: Number(p.args.srcEid),
          timestamp: Number(p.args.timestamp),
        };
      } catch (parseErr: any) {
        result.warnings.push(`Failed to parse destination log: ${parseErr?.message ?? String(parseErr)}`);
        return null;
      }
    }).filter(Boolean) as any[];
  } catch (e: any) {
    result.warnings.push(`Destination fetch failed: ${e?.message ?? String(e)}`);
  }

  return NextResponse.json(result);
}
