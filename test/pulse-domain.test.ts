import { describe, expect, it } from "vitest";
import { getCollateral, SOMNIA_MAINNET_CHAIN_ID, SOMNIA_SHANNON_CHAIN_ID } from "../lib/chain";
import { encodeRule, isReactivityCaller, toContractPolicy } from "../lib/session";

describe("pulse chain config", () => {
  it("uses different collateral tokens for testnet and mainnet", () => {
    expect(getCollateral(SOMNIA_SHANNON_CHAIN_ID)).toMatchObject({
      symbol: "tUSDC",
      address: "0x70a86D8842FB63C4Ad2b7cdddF530eBf1BB25d8E",
    });
    expect(getCollateral(SOMNIA_MAINNET_CHAIN_ID)).toMatchObject({
      symbol: "USDso",
      address: "0x00000022dA000002656c64D9eA6011ea952D008A",
    });
  });
});

describe("session policy encoding", () => {
  it("encodes deterministic autopilot rules for the contract", () => {
    expect(encodeRule("hold")).toBe(0);
    expect(encodeRule("martingale-off")).toBe(1);
    expect(encodeRule("stop-on-loss")).toBe(2);
  });

  it("converts expiry to bigint for viem tuple writes", () => {
    expect(
      toContractPolicy({
        maxStakePerWindow: BigInt(25_000_000),
        maxWindows: 4,
        expiry: 1_788_854_400,
        rule: "hold",
        allowedMarketIds: [],
      }),
    ).toEqual({
      maxStakePerWindow: BigInt(25_000_000),
      maxWindows: 4,
      expiry: BigInt(1_788_854_400),
      rule: 0,
    });
  });
});

describe("reactivity caller guard", () => {
  it("recognizes the Somnia reactivity precompile address", () => {
    expect(isReactivityCaller("0x0000000000000000000000000000000000000100")).toBe(true);
    expect(isReactivityCaller("0x0000000000000000000000000000000000000001")).toBe(false);
  });
});
