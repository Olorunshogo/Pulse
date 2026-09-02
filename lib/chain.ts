import { somniaMainnet, somniaShannon } from "@somnia-chain/markets-sdk/chains";
import { createPublicClient, erc20Abi, http, type Address, type Chain } from "viem";

export const SOMNIA_SHANNON_CHAIN_ID = 50312;
export const SOMNIA_MAINNET_CHAIN_ID = 5031;
export const SOMNIA_REACTIVITY_PRECOMPILE = "0x0000000000000000000000000000000000000100" as const;

export const COLLATERAL_BY_CHAIN = {
  [SOMNIA_SHANNON_CHAIN_ID]: {
    address: "0x70a86D8842FB63C4Ad2b7cdddF530eBf1BB25d8E",
    symbol: "tUSDC",
  },
  [SOMNIA_MAINNET_CHAIN_ID]: {
    address: "0x00000022dA000002656c64D9eA6011ea952D008A",
    symbol: "USDso",
  },
} as const satisfies Record<number, { address: Address; symbol: string }>;

export function getPulseChain(chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? SOMNIA_SHANNON_CHAIN_ID)): Chain {
  if (chainId === SOMNIA_MAINNET_CHAIN_ID) return somniaMainnet;
  return somniaShannon;
}

export function getCollateral(chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? SOMNIA_SHANNON_CHAIN_ID)) {
  return COLLATERAL_BY_CHAIN[chainId as keyof typeof COLLATERAL_BY_CHAIN] ?? COLLATERAL_BY_CHAIN[SOMNIA_SHANNON_CHAIN_ID];
}

export function getExplorerUrl() {
  return process.env.NEXT_PUBLIC_EXPLORER_URL ?? "https://shannon-explorer.somnia.network";
}

export function getTxUrl(hash: `0x${string}`) {
  return `${getExplorerUrl().replace(/\/$/, "")}/tx/${hash}`;
}

export async function readCollateralDecimals(rpcUrl = process.env.NEXT_PUBLIC_RPC_URL) {
  if (!rpcUrl) {
    throw new Error("NEXT_PUBLIC_RPC_URL is required to read collateral decimals");
  }

  const chain = getPulseChain();
  const collateral = getCollateral(chain.id);
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  });

  return publicClient.readContract({
    address: collateral.address,
    abi: erc20Abi,
    functionName: "decimals",
  });
}
