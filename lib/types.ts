import type { Address, Hex } from "viem";

export type PulsePair = "BTC" | "ETH";
export type PulseWindow = "15m" | "1h";
export type WindowStatus = "listed" | "trading" | "locked" | "resolved" | "voided";
export type CallSide = "up" | "down";
export type SessionRule = "hold" | "martingale-off" | "stop-on-loss";

export type MarketCard = {
  marketId: Hex;
  symbol: string;
  pair: PulsePair;
  window: PulseWindow;
  strike: string;
  expiryTs: number;
  status: WindowStatus;
  upPrice: number | null;
  downPrice: number | null;
};

export type Position = {
  marketId: Hex;
  side: CallSide;
  contracts: string;
  avgPrice: number;
  status: WindowStatus;
  redeemable: boolean;
  heldBy: "wallet" | "session";
};

export type SessionState = {
  address: Address;
  budget: string;
  remaining: string;
  windowsLeft: number;
  rule: SessionRule;
  armed: boolean;
  expiry: number;
};

export type Tape = {
  realized: string;
  unclaimed: string;
  todayCalls: number;
  todayWins: number;
  streak: number;
  autoClaims: number;
};

export type SessionPolicyInput = {
  maxStakePerWindow: bigint;
  maxWindows: number;
  expiry: number;
  rule: SessionRule;
  allowedMarketIds: Hex[];
};
