# Pulse

**Your winnings come to you.**

Pulse is a session layer for [DreamDEX Event Contracts](https://docs.dreamdex.io/trading/event-contracts) on [Somnia](https://somnia.network). Call the next candle in one tap, then let Somnia validators redeem your winnings the moment the window resolves. No claim button. No keeper bot. No signature.

Built for the [Somnia × DreamDEX Event Contracts Hackathon](https://dorahacks.io/hackathon/event-contracts/detail).

## The gap Pulse closes

Event Contracts are already consumer-shaped: BTC or ETH, 15 minutes or 1 hour, Up or Down, capped risk, zero fees, settled onchain.

But **settlement does not pay you**. A resolved market leaves winnings sitting as redeemable outcome tokens until you redeem them, one market at a time. Play five windows and the wallet looks empty while P&L is scattered across finished markets you have to go find.

That is not a UI complaint. It is a mechanical property of the primitive, and it is the biggest drop-off in the experience.

Pulse fixes it at the layer where it lives: onchain.

## How it works

A Pulse session is a per-user contract that holds your collateral and your positions under limits you set. It subscribes to market settlement through Somnia's Reactivity precompile at `0x0100`. When a window resolves, validators invoke the session's handler directly:

```
Binary market resolves
        │
        ▼
  settlement event
        │  Reactivity precompile 0x0100
        ▼
PulseSession.onEvent()
        ├── redeem winning / void ERC-6909 ids
        ├── credit the session balance
        └── optionally place the next window's call, within policy
```

No polling. No cron. No backend service. No browser tab open. The user signs once at the start of the session and does not sign again.

Because the session holds the outcome tokens itself, there is no operator delegation and no custody handoff. You fund it, you withdraw from it, and no path in the contract moves value to anyone but you.

## What it does

**Trade**

- Live BTC / ETH · 15m / 1h windows from `@somnia-chain/markets-sdk`
- Strike, countdown, implied Up/Down, top of book
- One-tap call with size presets (marketable limit, IOC by default)
- Positions keyed by `marketId`, never by pool address

**Session**

- Deposit a budget and set hard limits: max stake per window, number of windows, allowed markets, expiry
- Policy enforced onchain, stated in plain words on the card
- Disarm and Withdraw are always available, never blocked by an armed policy

**Settle**

- Winnings and voids redeemed automatically on resolution
- Autopilot can roll into the next window under the same limits
- Every automatic action links to its tx hash, marked "no signature required"

Direct mode is also available for users who want to keep positions in their own wallet, with a manual claim-all across every redeemable market.

## How Event Contracts are used

| Action | Mechanism |
|---|---|
| Discover windows | `loadMarkets` + `isBinaryMarket` |
| Trust status | `getMarketOnchain`, writes only when `status === 1` (Trading) |
| Price | Single book in Up probability `(0, 1)`; Down = `1 − Up` |
| Enter | `createOrder` on the outcome symbol |
| Exit / miss | Cancel residual orders after lock |
| Get paid (direct) | Scan settled markets, redeem winning ERC-6909 ids |
| Get paid (session) | Reactivity handler redeems on settlement |
| Roll | Resolve the successor market of the same pair and duration |
| Identity | All state keyed by `marketId`, because pools are reused |

HTTP APIs on DreamDEX cover spot only. Pulse reaches Event Contracts exclusively through the markets SDK.

## Run it in three commands

```bash
npm install
npm test          # contract invariants + client unit tests
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The live ETH 15m card renders read-only before you connect a wallet, so a reviewer can see real market data with no setup at all.

To trade, connect a wallet on Somnia Shannon testnet and mint tUSDC via `faucet(uint256 amount)` on the collateral contract (cap 10,000 per call). There is no separate faucet page. Pulse surfaces this in the UI when your balance is zero.

### Environment

```bash
cp .env.example .env.local
```

```bash
NEXT_PUBLIC_CHAIN_ID=50312
NEXT_PUBLIC_RPC_URL=https://api.infra.testnet.somnia.network
NEXT_PUBLIC_INDEXER_URL=
NEXT_PUBLIC_WS_RPC_URL=
NEXT_PUBLIC_WALLETCONNECT_ID=
NEXT_PUBLIC_EXPLORER_URL=https://shannon-explorer.somnia.network
NEXT_PUBLIC_SESSION_FACTORY=
```

Fill the indexer and WS URLs from the [Event Contract developer docs](https://docs.dreamdex.io/developers/event-contracts) for the SDK constructor. Pulse is a browser wallet app. Never commit a private key.

### Scripts

```bash
npm run dev          # local
npm run build        # production check
npm run typecheck
npm run lint
npm test             # forge test + vitest
npm run deploy:test  # deploy + verify PulseSessionFactory on 50312
```

## Deployments

| Contract | Address | Network |
|---|---|---|
| PulseSessionFactory | *(add before submission, source-verified)* | Shannon testnet `50312` |

| | Somnia testnet (submit on this) | Somnia mainnet |
|---|---|---|
| Chain ID | `50312` | `5031` |
| RPC | `https://api.infra.testnet.somnia.network` | `https://api.infra.mainnet.somnia.network` |
| Collateral | tUSDC `0x70a86D8842FB63C4Ad2b7cdddF530eBf1BB25d8E` (6 dp) | USDso `0x00000022dA000002656c64D9eA6011ea952D008A` (18 dp) |
| Reactivity precompile | `0x0100` | `0x0100` |

Core Event Contract addresses are CREATE3-stable across both networks. Do not hardcode per-window pools. Read them from the SDK or `BinaryMarketsModule`.

Pin `@somnia-chain/markets-sdk` at **0.28.0 or newer**. Below 0.28.0 prices miss the tick grid; below 0.23.0 `loadMarkets` fails.

## Demo

- Video: `docs/demo.mp4` *(add before submission)*
- Live testnet: *(add URL)*
- Example session: `/session/<address>` *(add before submission)*

Four beats: **call → session → settle without you → roll.**

## Testnet liquidity disclosure

Event Contract books on Shannon testnet can be thin. During development and while recording the demo we ran a two-sided market-making script (based on [dreamdex-bot-kit](https://github.com/somnia-chain/dreamdex-bot-kit)) to seed resting liquidity so taker orders would fill. It is in `scripts/maker/`.

The maker is not part of the product and is not required to run Pulse. Every fill shown in the demo is a real onchain fill against a real book. We are stating this plainly rather than letting a reviewer wonder where the counterparty came from.

## Product rules we will not break

1. Gate every write on live onchain status. The indexer lags.
2. Persist `marketId`, never a pool address.
3. Derive collateral scale from `decimals()`. Testnet and mainnet differ by `10^12`.
4. Treat voids as redeemable at 0.5, not as a loss.
5. Resolve the winning token id from onchain market state, never from UI side state.
6. The handler accepts calls only from `0x0100`, and one failing redeem never blocks the others.
7. `withdraw` is never blocked by an armed policy.
8. Default CTA is a marketable order, so a 15 minute window does not leave an accidental rest.

Full spec: [`docs/Pulse-PRD.md`](docs/Pulse-PRD.md).

## Stack

- Next.js 15 (App Router) + TypeScript
- wagmi + viem
- Solidity + Foundry (`PulseSession`, `PulseSessionFactory`)
- `@somnia-chain/markets-sdk` `>= 0.28.0`
- TanStack Query
- Tailwind CSS

```
app/                  routes + providers
components/           hero card, book, actions, session card, positions, activity
contracts/            PulseSession.sol, PulseSessionFactory.sol
lib/markets.ts        SDK wrapper (load, status gate, book, order)
lib/session.ts        factory + policy reads/writes
lib/redeem.ts         direct-mode settled scan + claim all
lib/tape.ts           session tape, P&L, streak
lib/chain.ts          chain, tokens, decimals()
scripts/maker/        testnet liquidity seeding (dev only, see disclosure)
docs/                 PRD, demo, screenshots
```

## For judges

| Criterion | Where to look |
|---|---|
| Use of Event Contracts and SDKs | `lib/markets.ts`. Full path: discover, status gate, book, order, cancel, redeem. |
| Technical implementation | `contracts/PulseSession.sol` and its Foundry tests. Precompile-gated handler, onchain policy, no keeper infrastructure anywhere in the repo. |
| Novelty | Settlement does not pay you. Pulse makes validators pay you. Watch beat 3 of the video: a redemption tx with no signature prompt. |
| UX | One screen, one window, one decision. The countdown is the primary object. The best interaction here is the one the user never has to perform. |
| Ecosystem | Turns a one-off call into a session, which is more windows played per user. |

Every claim on this page maps to a deployed contract, a tx hash, or a passing test. Anything not yet live is under Roadmap, in the future tense, and nowhere else.

## Roadmap (not in this submission)

- Mainnet deployment with USDso
- An MCP surface so agents can open and drive a Pulse session directly, using the `AGENTS.md` and `SKILL.md` conventions DreamDEX already ships
- Richer autopilot rules beyond the deterministic set shipped here
- Mint-vs-take router (buy Up, or mint a complete set and sell Down)
- Session keys so a phone can call without signing every tick
- Next-window push reminders

## Feedback to the DreamDEX team

[`FEEDBACK.md`](FEEDBACK.md) collects evidence-backed notes on the SDK and docs logged as we hit them during the build: version-specific tick behaviour, the decimals trap between networks, indexer lag versus onchain status, and the pool-reuse identity gotcha. Each entry cites the exact call and the observed behaviour.

## License

MIT
