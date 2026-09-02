import { createReactivity, unwrap, DEFAULT_SUBSCRIPTION_OPTIONS } from "@somnia-chain/markets-sdk/reactivity";
import type { SomniaMarkets } from "@somnia-chain/markets-sdk";
import type { Address, Hex, WalletClient } from "viem";
import { SOMNIA_REACTIVITY_PRECOMPILE } from "./chain";
import type { SessionPolicyInput } from "./types";

export const pulseSessionFactoryAbi = [
  {
    type: "function",
    name: "sessionOf",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "session", type: "address" }],
  },
  {
    type: "function",
    name: "createSession",
    stateMutability: "nonpayable",
    inputs: [
      {
        name: "policy",
        type: "tuple",
        components: [
          { name: "maxStakePerWindow", type: "uint256" },
          { name: "maxWindows", type: "uint32" },
          { name: "expiry", type: "uint64" },
          { name: "rule", type: "uint8" },
        ],
      },
      { name: "allowedMarketIds", type: "bytes32[]" },
    ],
    outputs: [{ name: "session", type: "address" }],
  },
] as const;

export const pulseSessionAbi = [
  {
    type: "function",
    name: "deposit",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "disarm",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "withdraw",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
] as const;

export function encodeRule(rule: SessionPolicyInput["rule"]) {
  if (rule === "stop-on-loss") return 2;
  return rule === "martingale-off" ? 1 : 0;
}

export function toContractPolicy(policy: SessionPolicyInput) {
  return {
    maxStakePerWindow: policy.maxStakePerWindow,
    maxWindows: policy.maxWindows,
    expiry: BigInt(policy.expiry),
    rule: encodeRule(policy.rule),
  };
}

export async function subscribeSessionToSettlement(
  exchange: SomniaMarkets,
  walletClient: WalletClient,
  session: Address,
  settlementEmitter: Address,
  topic0: Hex,
) {
  const reactivity = createReactivity(exchange.client, { wallet: walletClient });

  return unwrap(
    await reactivity.subscribe({
      handlerContractAddress: session,
      filter: {
        emitter: settlementEmitter,
        eventTopics: [topic0],
      },
      options: DEFAULT_SUBSCRIPTION_OPTIONS,
    }),
  );
}

export function isReactivityCaller(caller: Address) {
  return caller.toLowerCase() === SOMNIA_REACTIVITY_PRECOMPILE.toLowerCase();
}
