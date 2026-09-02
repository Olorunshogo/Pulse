import {
  isBinaryMarket,
  SOMNIA_TESTNET_ADDRESSES,
  SOMNIA_MAINNET_ADDRESSES,
  SomniaMarkets,
  type BinaryMarket,
  type SomniaMarketsConfig,
  type UnifiedOrder,
} from "@somnia-chain/markets-sdk";
import type { WalletClient } from "viem";
import { getPulseChain, SOMNIA_MAINNET_CHAIN_ID } from "./chain";
import type { CallSide, MarketCard, PulsePair, PulseWindow, WindowStatus } from "./types";

type PulseMarketFilters = {
  pair?: PulsePair;
  window?: PulseWindow;
};

export function createPulseExchange(walletClient?: WalletClient) {
  const chain = getPulseChain();
  const config: SomniaMarketsConfig = {
    chain,
    addresses: chain.id === SOMNIA_MAINNET_CHAIN_ID ? SOMNIA_MAINNET_ADDRESSES : SOMNIA_TESTNET_ADDRESSES,
    indexerUrl: requiredPublicEnv("NEXT_PUBLIC_INDEXER_URL"),
    wsRpcUrl: requiredPublicEnv("NEXT_PUBLIC_WS_RPC_URL"),
    walletClient,
  };

  return new SomniaMarkets(config);
}

export async function loadPulseMarkets(exchange = createPulseExchange(), filters: PulseMarketFilters = {}) {
  const markets = await exchange.loadMarkets(true);

  return Object.values(markets)
    .filter((market) => market.type === "binary" && isBinaryMarket(market.info))
    .map((market) => toMarketCard(market.info as BinaryMarket))
    .filter((market) => isSupportedMarket(market, filters))
    .sort((a, b) => a.expiryTs - b.expiryTs);
}

export async function getMarketCard(exchange: SomniaMarkets, marketId: `0x${string}`) {
  const markets = await loadPulseMarkets(exchange);
  return markets.find((market) => market.marketId.toLowerCase() === marketId.toLowerCase()) ?? null;
}

export async function loadTopOfBook(exchange: SomniaMarkets, outcomeSymbol: string, depth = 3) {
  const book = await exchange.fetchOrderBook(outcomeSymbol, depth);
  const bestAsk = book.asks[0]?.[0] ?? null;
  const bestBid = book.bids[0]?.[0] ?? null;
  const mid = bestAsk !== null && bestBid !== null ? (bestAsk + bestBid) / 2 : bestAsk ?? bestBid;

  return {
    symbol: book.symbol,
    bids: book.bids.slice(0, depth),
    asks: book.asks.slice(0, depth),
    upPrice: clampProbability(mid),
    downPrice: mid === null ? null : clampProbability(1 - mid),
    timestamp: book.timestamp,
  };
}

export async function placeMarketableCall(
  exchange: SomniaMarkets,
  market: MarketCard,
  side: CallSide,
  stake: number,
): Promise<UnifiedOrder> {
  const status = await exchange.client.getMarketOnchain(market.marketId);
  if (status.status !== 1) {
    throw new Error(`Market ${market.marketId} is not trading`);
  }

  const outcomeSymbol = getOutcomeSymbol(market.symbol, side);
  return exchange.createOrder(outcomeSymbol, "market", "buy", stake, undefined, {
    timeInForce: "IOC",
  });
}

export async function cancelOrder(exchange: SomniaMarkets, orderId: string, outcomeSymbol: string) {
  return exchange.cancelOrder(orderId, outcomeSymbol);
}

export function getOutcomeSymbol(marketSymbol: string, side: CallSide) {
  return `${marketSymbol}#${side === "up" ? "YES" : "NO"}`;
}

function toMarketCard(market: BinaryMarket): MarketCard {
  const pair = normalizePair(market.asset);
  const window = normalizeWindow(market.interval);
  const status = normalizeStatus(market.status, Number(market.tradingStart), Number(market.expiry));
  const lastUpPrice = market.lastPrice ? Number(market.lastPrice) / 10 ** market.quoteDecimals : null;

  return {
    marketId: market.marketId,
    symbol: marketSymbol(market),
    pair,
    window,
    strike: market.strike,
    expiryTs: Number(market.expiry),
    status,
    upPrice: clampProbability(lastUpPrice),
    downPrice: lastUpPrice === null ? null : clampProbability(1 - lastUpPrice),
  };
}

function marketSymbol(market: BinaryMarket) {
  return `${market.asset}-${market.interval ?? "window"}/${market.collateral}`;
}

function normalizePair(asset: string): PulsePair {
  return asset.toUpperCase() === "BTC" ? "BTC" : "ETH";
}

function normalizeWindow(interval?: string | null): PulseWindow {
  return interval === "1h" ? "1h" : "15m";
}

function normalizeStatus(status: string, tradingStart?: number, expiry?: number): WindowStatus {
  const now = Math.floor(Date.now() / 1000);
  if (status === "Voided") return "voided";
  if (status === "Resolved" || status === "Finalized") return "resolved";
  if (status === "Locked" || status === "Settling") return "locked";
  if (status === "Trading") return "trading";
  if (tradingStart && expiry && now >= tradingStart && now < expiry) return "trading";
  if (expiry && now >= expiry) return "locked";
  return "listed";
}

function requiredPublicEnv(name: "NEXT_PUBLIC_INDEXER_URL" | "NEXT_PUBLIC_WS_RPC_URL") {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required to create a Pulse exchange`);
  }

  return value;
}

function isSupportedMarket(market: MarketCard, filters: PulseMarketFilters) {
  if (filters.pair && market.pair !== filters.pair) return false;
  if (filters.window && market.window !== filters.window) return false;
  return market.pair === "BTC" || market.pair === "ETH";
}

function clampProbability(value: number | null) {
  if (value === null || Number.isNaN(value)) return null;
  return Math.min(1, Math.max(0, value));
}
