import type { SomniaMarkets } from "@somnia-chain/markets-sdk";
import type { Address, Hex } from "viem";

export type RedeemableMarket = {
  marketId: Hex;
  outcomeIdx: 0 | 1;
  amount: bigint;
  symbol: string;
  expectedPayout: string;
  voided: boolean;
};

export type ClaimAllResult = {
  claimed: RedeemableMarket[];
  failed: Array<{ market: RedeemableMarket; error: unknown }>;
};

export async function listRedeemableMarkets(exchange: SomniaMarkets, owner: Address): Promise<RedeemableMarket[]> {
  const claimable = await exchange.client.getClaimable(owner);

  return claimable.map((position) => ({
    marketId: position.marketId as Hex,
    outcomeIdx: position.outcomeIdx,
    amount: position.amount,
    symbol: position.pool,
    expectedPayout: position.estPayout.toString(),
    voided: position.status === "Voided",
  }));
}

export async function claimAllRedeemable(exchange: SomniaMarkets, markets: RedeemableMarket[]): Promise<ClaimAllResult> {
  const claimed: RedeemableMarket[] = [];
  const failed: ClaimAllResult["failed"] = [];

  for (const market of markets) {
    try {
      await exchange.trader.redeemMany({
        entries: [{ marketId: market.marketId, outcomeIdx: market.outcomeIdx, amount: market.amount }],
      });
      claimed.push(market);
    } catch (error) {
      failed.push({ market, error });
    }
  }

  return { claimed, failed };
}
