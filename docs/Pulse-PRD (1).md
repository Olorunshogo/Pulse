# Pulse
## Product Requirements Document

**DreamDEX Event Contracts Hackathon · Somnia × DoraHacks**

| Field | Value |
|---|---|
| Product | Pulse |
| One-liner | The session layer for DreamDEX Event Contracts: your winnings come to you |
| Version | 2.0 · MVP |
| Status | Ready to build |
| Horizon | 7 days (submission deadline 8 Sep 2026, 19:00) |
| Networks | Somnia Shannon testnet (50312) for submission; mainnet-ready types |
| Stack | Next.js 15 · TypeScript · wagmi/viem · Solidity · `@somnia-chain/markets-sdk` ≥ 0.28.0 |
| Collateral | tUSDC on testnet · USDso on mainnet (never hardcode decimals) |

---

## 0. What changed from v1, and why

v1 was a consumer front-end for Event Contracts. It was well researched but structurally at risk on three counts:

1. **Crowded lane.** A clean wrapper around the venue's own product is the most predictable submission in a field of 284 hackers. At least one visible BUIDL ("Runs") is positioned on the same "one market, one window" idea.
2. **Ignored the ecosystem's headline primitives.** Somnia markets itself as the Agentic L1 and ships onchain Reactivity, where validators invoke your contract when an event fires. DreamDEX shipped MCP, `AGENTS.md`, `SKILL.md` and CCXT specifically for agents. v1 used none of it and polled a client worker on a 15 second tick.
3. **Liquidity treated as a risk row.** Every step of the v1 demo after "tap Up" depends on an IOC filling on a testnet book that may be empty.

v2 keeps everything that was right in v1 (the domain rules, the claim insight, the one-screen decision) and changes the spine:

- The claim worker becomes an onchain reactive settlement handler. Winnings are pushed by validators, not scavenged by a browser tab.
- That same handler carries an optional autopilot roll into the next window under user-set hard limits, which turns Pulse from a UI into a session primitive.
- Liquidity becomes Workstream C, owned, seeded and disclosed, not a mitigation sentence.

The product thesis in one line: **Event Contracts roll every 15 minutes but the user experience does not roll with them. Pulse makes a sequence of windows behave like one continuous session.**

---

## 1. Problem

DreamDEX Event Contracts are capped-risk Up/Down markets on BTC and ETH over 15 minute and 1 hour windows: zero fees, fully collateralised, settled onchain. The primitive is already consumer shaped. The surface around it is not.

Four gaps block repeat use, in order of how much they cost the user:

1. **Settlement does not pay you.** Winnings sit as redeemable outcome tokens across settled markets until the user manually redeems each one. After five windows the wallet looks empty while the P&L is scattered. This is the single largest drop-off in the whole primitive and it is mechanical, not cosmetic.
2. **The window dies before you can act on it.** A 15 minute market ends, a successor lists, and the user has to find it, re-enter size, re-sign. The natural behaviour (call the next one too) is the one the current flow punishes.
3. **Exchange density for a two-outcome decision.** A full CLOB ladder is the wrong instrument for "will ETH finish this candle up."
4. **No session identity.** Rolling windows reset. There is no today tape, no streak, no answer to "how did my last five calls go."

Pulse wraps the live primitive. It does not replace the venue and it does not invent a market type.

---

## 2. Goals

### Product goals

- Connect, pick a live window, take a side, see the fill in under 30 seconds.
- Winnings arrive without the user asking for them.
- A user can commit to the next N windows with a hard loss cap and then close the tab.
- Realised plus unrealised P&L is one number, always reconciled from chain.

### Hackathon goals

- Demonstrate meaningful, correct use of `@somnia-chain/markets-sdk` across discover, book, order, redeem.
- Demonstrate Somnia Reactivity on a real settlement event, not a toy.
- Ship a working testnet build a judge can clone and run in three commands.
- File an evidence-backed SDK and docs feedback report as a deliverable.

### Non-goals (MVP)

- New onchain market type or custom AMM.
- Spot aggregator or swap clone.
- Generic contract auditor or risk scorer.
- LLM-driven strategy. Autopilot is a deterministic rule the user sets, not a model making calls. See section 6.4.
- Copy trading, social rooms, strategy marketplace.
- Cross-chain collateral.
- Mainnet custody. Testnet only, with mainnet-ready types.
- Native mobile apps (responsive web only).

---

## 3. Who it is for

| Persona | Job to be done | What they refuse |
|---|---|---|
| Curious trader | Call the next BTC/ETH candle with capped risk | Learning a CLOB to place a 25 dollar view |
| Repeat caller | Stay in across a run of windows and know if they are winning | Redeeming five settled markets by hand |
| Away trader | Take a view on the next hour without babysitting a tab | Handing custody to anything |
| Judge / reviewer | See Event Contracts and Somnia Reactivity used for a real experience | A mocked book, a Figma, an architecture diagram of something not running |

Primary persona for the demo: **repeat caller**. The first-session flow must still be obvious to a stranger.

---

## 4. Product principle

**One screen. One window. One decision. The rest is automatic.**

If a control does not help the user pick Up or Down before the clock hits zero, it is a drawer, a toast, or a post-trade state. Anything that happens after the clock hits zero should require zero user action.

---

## 5. The spine: reactive settlement

This is the differentiator. Everything else in Pulse is table stakes execution around it.

### 5.1 The mechanism

Somnia Reactivity lets a contract subscribe to onchain events and be invoked directly by validators through the precompile at `0x0100`. No keeper bot, no polling service, no cron. The established pattern in the ecosystem (see DreamDEX's own `SpotStopOrderRegistry`, which subscribes to `MarkPriceUpdated` on the spot pool) is a handler contract inheriting `SomniaEventHandler` whose `onEvent` callback runs when the subscribed event fires.

Pulse applies that pattern to settlement:

```
Binary market resolves
        │
        ▼
  settlement event
        │  (Reactivity precompile 0x0100)
        ▼
PulseSession.onEvent()
        ├── redeem winning / void ERC-6909 ids held by this session
        ├── credit collateral to the session balance
        └── if autopilot armed and policy allows:
                place next-window order on the successor market
```

### 5.2 Why a session vault, not delegation

The obvious design is to let a shared handler redeem on behalf of a user's EOA. That requires ERC-6909 operator delegation, which is an unverified dependency and a custody smell.

Instead, positions taken in session mode are held by a per-user `PulseSession` contract. The session holds the outcome tokens, so it can redeem them with no delegation at all. The user funds it, the user withdraws from it, and nobody else can move value out of it.

This is the same shape as prior policy-wallet work (GuardRail, AgentWallet), so the contract is not novel research. It is a known pattern applied to a new event source.

### 5.3 Session policy (set by the user at open, enforced onchain)

| Field | Meaning | Enforced |
|---|---|---|
| `budget` | Collateral deposited. Absolute maximum loss. | Vault holds only this |
| `maxStakePerWindow` | Cap on a single call | Revert above |
| `maxWindows` | How many windows autopilot may play | Counter, then disarm |
| `allowedMarkets` | Pair + duration whitelist | Revert on others |
| `expiry` | Wall-clock deadline after which no new orders | Revert after |
| `side` | Fixed side, or follow-book rule (see 6.4) | Deterministic |

The user can `disarm()` or `withdraw()` at any time, including mid-session. Withdraw is never blocked by an armed policy.

### 5.4 Two modes, and the cut line

| Mode | Custody | Claim | Ships when |
|---|---|---|---|
| Direct | User's own wallet | Manual claim-all (client scan + redeem) | Day 2. No new contracts. |
| Session | PulseSession vault | Reactive auto-claim | Day 4. Autopilot Day 5. |

Direct mode alone is a complete, submittable product. If the contract track slips, Pulse still ships as v1 did and the README describes the reactive path honestly as designed but not deployed. See section 15.

---

## 6. Scope

### 6.1 Must ship (P0) · Direct mode

1. Wallet connect on Somnia testnet (50312), with switch-chain prompt.
2. Live Event Contract discovery: BTC / ETH × 15m / 1h via `loadMarkets` + `isBinaryMarket`.
3. Active window card: pair, window, countdown, strike (window open price), status chip.
4. Live book summary: best Up, best Down, implied percentage, spread, top-of-book size.
5. Place order: side plus size presets plus custom. Default CTA is a marketable limit, IOC.
6. Cancel residual orders on the active window.
7. Positions: open, locked, settled-unclaimed, settled-claimed, keyed by `marketId`.
8. Claim all winners and voids, with per-market error isolation.
9. Session tape: this window, today, realised vs unclaimed, streak.
10. Empty, loading, locked, resolved, voided and error states, with decoded revert reasons.
11. Testnet faucet path for tUSDC (`faucet(uint256)`, cap 10,000 per call).

### 6.2 Must ship (P0) · Reactive settlement

1. `PulseSessionFactory` deploys a minimal-proxy `PulseSession` per user.
2. Open a session: deposit collateral, set policy, single confirm.
3. Trading from session: the session places the order, the session holds the outcome tokens.
4. `PulseSession` subscribes to the settlement event via `0x0100` and inherits the handler interface.
5. `onEvent` redeems winning and void ids and credits the session balance.
6. Withdraw at any time, no lock.
7. UI proof surface: the settlement tx and the redemption tx are both linked, showing the user never signed the second one.

### 6.3 Should ship (P1) if P0 is green by Day 4

1. Autopilot roll. On settlement, if armed and within policy, place the next window's order on the successor market.
2. Live "windows remaining" and "budget remaining" on the session card.
3. Next-window teaser and one-tap manual roll in direct mode.
4. Merge leftover complete sets back to collateral.

### 6.4 Autopilot rules (deterministic, no model)

Autopilot must never look like a black box making trades. The user picks exactly one rule at arm time and the UI states it in plain words on the session card:

| Rule | Behaviour | Copy on card |
|---|---|---|
| `hold` | Same side every window | "Calling Up every window" |
| `martingale-off` | Same side, fixed stake, never increases | "Fixed 25 per window" |
| `stop-on-loss` | Disarm after first losing window | "Stops after one miss" |

There is no sentiment model, no LLM, no signal. Anything smarter is post-submission. This is a deliberate choice: an honest deterministic rule that provably executes beats a clever one that judges cannot verify in three minutes.

### 6.5 Nice (P2), only after the video is drafted

- Share card of a settled call.
- Keyboard: `U` / `D` plus `1` `2` `3` for presets.
- Crowd chip ("book is heavy this side"), informational only.

---

## 7. User journeys

### 7.1 First trade (direct mode)

1. Land on Pulse. Live ETH 15m card renders read-only before connect.
2. Connect. Wrong network gives a switch prompt to 50312.
3. Zero collateral gives a faucet explainer, not a dead button.
4. Choose 25. Tap Up. Helper reads: stake 25, max loss 25, win pays 1.00 per contract.
5. Confirm. Toast: filled, partial, or missed with the reason.
6. Position appears on the card. Countdown keeps running.

### 7.2 Open a session

1. Tap **Start session** on the home card.
2. Set budget 200, max stake per window 25, windows 4, expiry in 2 hours.
3. Single confirm deploys and funds the session.
4. Card switches to session mode: budget remaining, windows remaining, policy in plain words.

### 7.3 Settlement without the user (the money shot)

1. Window locks. Place button dies, cancel still works on residuals.
2. Market resolves. The user does nothing.
3. Validators invoke `onEvent`. Winning ids are redeemed. Session balance updates.
4. UI shows both hashes: the settlement tx, and the redemption tx the user never signed.
5. If autopilot is armed, the next window's order appears in the tape with its own hash.

### 7.4 Close out

1. Tap **Withdraw**. Full balance returns to the wallet.
2. Today tape shows every call, every settlement, every auto-redeem, each linked to `marketId`.

---

## 8. Information architecture

```
/                       Home · active window + action + session card
/markets                All live binary markets (grid)
/positions              Open, locked, unclaimed, session-held
/activity               Session tape: fills, settlements, auto-claims, rolls
/market/[marketId]      Deep link to one window
/session/[address]      Public read-only view of a session and its policy
```

MVP can collapse to one page with drawers if routing slips. Deep link by `marketId` is required either way, never by pool address. `/session/[address]` is worth keeping even if everything else collapses: it is a shareable proof surface for the demo.

---

## 9. Screen specs

### 9.1 Home

Top bar: Pulse mark, network pill, wallet, claim badge (count of redeemable markets in direct mode), session pill (active or not).

**Hero card**

- Pair and window (`ETH · 15m`)
- Status chip: Trading / Locked / Resolved / Voided
- Countdown `mm:ss`, red under 60s
- Strike: window open price
- Implied: Up `0.xx`, Down = `1 − Up`, always derived, never a second feed

**Action row**

- Size presets `10` `25` `50` `100` plus custom
- Two buttons: Up and Down
- Helper: "Stake 25 · max loss 25 · win pays 1.00 per contract"
- Effective contracts (stake / price) shown before confirm

**Session card (when open)**

- Budget remaining / budget
- Windows remaining
- Policy in one sentence
- Disarm and Withdraw, both always enabled

**Under the card**

- Mini book: 3 asks, 3 bids, on Up terms
- Your position on this window
- Next window teaser under 2 minutes or when status is not Trading

### 9.2 Activity

Reverse-chronological: placed, filled, cancelled, locked, resolved, auto-claimed, auto-rolled, withdrawn. Auto rows carry a distinct marker and the note "no signature required." Every row links to `marketId` and to the explorer.

### 9.3 Claim sheet (direct mode)

Redeemable markets with expected payout, total to wallet, single confirm, per-market try/catch so one revert cannot hide the rest.

---

## 10. Domain rules (must be implemented correctly)

1. **Identity.** Key all state by `marketId` and symbol. Pools are reused across windows. Never persist a pool address as the market key.
2. **Status gate.** The indexer lags. Read onchain status before every write. Only `Trading = 1` accepts new orders; Locked allows cancels; Resolved and Voided allow redeem.
3. **Pricing.** The book is quoted in Up probability on `(0, 1)` on the tick grid. Down = `1 − Up`. Pin the SDK at `>= 0.28.0` or prices miss the tick grid; below `0.23.0`, `loadMarkets` fails.
4. **Risk copy.** Max loss equals stake. A winning contract redeems 1 unit of collateral. Never use the words leverage or liquidation.
5. **Decimals.** Testnet tUSDC is 6dp, mainnet USDso is 18dp, a factor of `10^12`. Always read `decimals()` from the token. A hardcoded scale misprices silently.
6. **Claim vs receive.** Settlement does not push funds. Direct mode scans and redeems; session mode redeems in the handler.
7. **Voids.** Voided markets redeem both sides at 0.5. Redeemable, not a loss.
8. **Successor markets.** Series roll. When the visible window dies, resolve the next live market of the same pair and duration from `loadMarkets`.
9. **Winner resolution.** Resolve the winning token id from onchain market state, never from UI side state.
10. **Handler safety.** `onEvent` must accept only the `0x0100` precompile as caller, must be reentrancy-safe, and must wrap every per-market redeem in try/catch so one failure cannot block the rest or brick the subscription.

---

## 11. Technical requirements

### 11.1 Stack

- Next.js 15 (App Router) plus TypeScript
- wagmi plus viem
- `@somnia-chain/markets-sdk` for Event Contracts
- Solidity for `PulseSession` and `PulseSessionFactory` (Foundry)
- TanStack Query for market and book polling
- Tailwind, small component set, no heavy design system

### 11.2 SDK surface

- `loadMarkets(true)` plus `isBinaryMarket`
- `getMarketOnchain(marketId)` for live status
- `fetchOrderBook(upSymbol, depth)`
- `createOrder` and cancel
- Watches for book, fills and user orders where the installed version exposes them
- Redeem path: scan settled markets, redeem winning ERC-6909 ids
- `mintCompleteSet` / `mergeCompleteSet` only if inventory tools are exposed (P1)

The DreamDEX HTTP API covers spot only. Event Contracts go through the markets SDK exclusively.

### 11.3 Chain config

| | Testnet (submission) | Mainnet (types only) |
|---|---|---|
| Chain ID | `50312` | `5031` |
| RPC | `https://api.infra.testnet.somnia.network` | `https://api.infra.mainnet.somnia.network` |
| Collateral | tUSDC `0x70a86D8842FB63C4Ad2b7cdddF530eBf1BB25d8E` (6dp) | USDso `0x00000022dA000002656c64D9eA6011ea952D008A` (18dp) |
| Reactivity precompile | `0x0100` | `0x0100` |
| Explorer | `https://shannon-explorer.somnia.network` | — |

Core Event Contract addresses are CREATE3-stable across both networks. Read markets from the SDK or `BinaryMarketsModule`. Never hardcode per-window pools.

### 11.4 Contracts

```
PulseSessionFactory.sol
  createSession(policy) -> clone address
  sessionOf(user) -> address

PulseSession.sol            (minimal proxy target)
  owner                     the user, immutable after init
  policy                    budget, maxStakePerWindow, maxWindows, allowedMarkets, expiry, rule
  deposit(amount)
  place(marketId, side, stake)      policy-checked, status-gated
  onEvent(...)                      only callable by 0x0100
    ├── redeemAll()                 winning + void ids held by this session
    └── maybeRoll()                 if armed, in policy, successor is Trading
  disarm()                          owner only, always available
  withdraw(amount)                  owner only, never blocked by policy
```

Invariants to assert in tests:

- No path moves value to any address other than owner.
- `place` reverts when stake exceeds `maxStakePerWindow`, when the market is not whitelisted, past expiry, or when `maxWindows` is exhausted.
- `withdraw` succeeds while armed, mid-window, and after expiry.
- `onEvent` reverts for any caller other than the precompile.
- A failing redeem on one market does not revert the others.

### 11.5 Client data model

```ts
type WindowStatus = "listed" | "trading" | "locked" | "resolved" | "voided";

type MarketCard = {
  marketId: `0x${string}`;
  symbol: string;            // ETH-15m
  pair: "BTC" | "ETH";
  window: "15m" | "1h";
  strike: string;            // window open price, display
  expiryTs: number;
  status: WindowStatus;
  upPrice: number;           // (0,1)
  downPrice: number;         // 1 - up
};

type Position = {
  marketId: `0x${string}`;
  side: "up" | "down";
  contracts: string;
  avgPrice: number;
  status: WindowStatus;
  redeemable: boolean;
  heldBy: "wallet" | "session";
};

type SessionState = {
  address: `0x${string}`;
  budget: string;
  remaining: string;
  windowsLeft: number;
  rule: "hold" | "fixed" | "stop-on-loss";
  armed: boolean;
  expiry: number;
};

type Tape = {
  realized: string;
  unclaimed: string;
  todayCalls: number;
  todayWins: number;
  streak: number;
  autoClaims: number;        // count of redemptions the user did not sign
};
```

Persist only: last pair and window, last size preset, wallet-scoped tape cache. Reconcile from chain on load.

### 11.6 Direct-mode claim worker (fallback path, still shipped)

On connect and on a 15s tick: load markets including recently settled, filter to user ERC-6909 balances on winning or void ids, build the redeemable list, badge equals its length, claim-all runs sequential redeems with per-item try/catch and a summary toast.

### 11.7 Quality bar

- No mocked books in the submitted build. `NEXT_PUBLIC_MOCK=1` may exist for UI work, default off.
- Every write path surfaces the tx hash and an explorer link.
- Reverts surface decoded SDK and contract errors, never bare `execution reverted`.
- Contracts have a Foundry test suite covering every invariant in 11.4.
- The submitted contract addresses are source-verified on the Shannon explorer.

---

## 12. UX and copy rules

- Say **call**, **window**, **stake**, **payout**. Never leverage, liquidation, or "bet" in a primary CTA.
- Up and Down stay those words. They match DreamDEX.
- Helper always repeats capped risk: "You can only lose the stake."
- Session copy always states the cap first: "200 budget · 25 max per window · 4 windows."
- Auto rows in the tape say "no signature required," never "automatic profit."
- Time is local; the countdown is UTC-anchored to market expiry.

Visual direction: dark and dense, one accent (green Up, red Down) against deep navy, Space Grotesk and JetBrains Mono. It should read as a trading instrument, not a marketing site. Do not clone the DoraHacks page.

---

## 13. Judging map

The published criteria include novelty and creative use solving a real problem, effective use of Event Contracts and the available APIs and SDKs, strength and functionality of the technical implementation, and intuitiveness, accessibility and overall user experience. Verify the exact weighting on the DoraHacks detail page on Day 1 and adjust emphasis if it differs.

| Criterion | How Pulse hits it |
|---|---|
| Novelty, real problem | Settlement does not pay you. Pulse makes validators pay you. That is a mechanical gap in the primitive, not a skin. |
| Use of Event Contracts and SDKs | Full markets SDK path: discover, status-gate, book, order, cancel, redeem across marketIds. Plus Somnia Reactivity on a real settlement event. |
| Technical implementation | Onchain policy vault, precompile-gated handler, verified contracts, Foundry invariant tests, no keeper infrastructure anywhere. |
| UX | One-screen call, countdown as the primary object, and the strongest UX claim available: the best interaction is the one the user does not have to perform. |
| Ecosystem | Lowers time-to-first-trade and converts a one-off call into a session. More windows played per user is exactly the adoption the sponsors are funding. |

---

## 14. Build plan

Three parallel tracks. Dave owns contracts, since the policy-vault shape is already familiar work.

| Day | Track A · App | Track B · Contracts | Track C · Liquidity & demo |
|---|---|---|---|
| 1 | Shell, wallet, `loadMarkets`, binary filter, hero card, countdown | Spike 1 and Spike 2 (see §15) | Verify a real fill on testnet. Stand up maker script |
| 2 | Book, size presets, IOC place, cancel | `PulseSession` skeleton, policy, deposit, withdraw, tests | Maker running on ETH 15m both sides |
| 3 | Positions, claim scan, redeem, session math | `place` with policy checks and status gate | Record a spare successful-fill clip |
| 4 | Session card, open-session flow, session-held positions | `onEvent` handler, subscription, `redeemAll`, deploy and verify | Demo script v1 written |
| 5 | Activity tape with auto rows, mobile layout, error decodes | Autopilot roll (P1), invariant tests green | Rehearse the full journey end to end |
| 6 | Polish, empty and error states, `/session/[address]` | Freeze. Verify on explorer. Write `FEEDBACK.md` entries | Record video. README, env sample |
| 7 | Buffer only | Buffer only | Submit by 12:00, seven hours before the 19:00 deadline |

Cut order if a day slips, strictly top down:

1. Cut P2 entirely.
2. Cut autopilot roll, keep reactive auto-claim.
3. Cut session mode, ship direct mode, describe the reactive path honestly as designed and not deployed.
4. Never cut: claim-all, status gating, the demo video.

---

## 15. Day 1 spikes (timeboxed, both answered before any UI work commits)

**Spike 1 · Liquidity** (half a day, Track C). Connect, `loadMarkets`, `fetchOrderBook` on a live ETH 15m, place one small marketable order. Does it fill? If the book is thin, stand up a two-sided maker using `dreamdex-bot-kit` to seed resting liquidity for development and recording. This is legitimate on testnet and must be disclosed in the README. If this is not resolved by end of Day 1, the demo is at risk and everything else is premature.

**Spike 2 · Settlement event** (half a day, Track B). Does the binary market emit an event on resolution that Reactivity can subscribe to through `0x0100`, and can `PulseSession` register that subscription? The established precedent is `SpotStopOrderRegistry` subscribing to `MarkPriceUpdated`, so the pattern exists, but binary settlement specifically is unverified. If the answer is no, fall to cut level 3 immediately on Day 1 rather than discovering it on Day 4.

Record both answers in the decision log the same day.

---

## 16. Demo script (2:40)

1. **0:00–0:15** The gap: Event Contracts settle, but settlement does not pay you. Winnings sit scattered across finished markets.
2. **0:15–0:35** Pulse home. Live ETH 15m, strike, implied, countdown running.
3. **0:35–1:05** Connect, size 25, tap Up, tx hash, position on the card.
4. **1:05–1:35** Start a session: 200 budget, 25 per window, 4 windows. One confirm. Policy shown in plain words.
5. **1:35–2:10** The beat that wins it. Cut to a window resolving. Hands off the keyboard. The redemption tx appears with no signature prompt. Show both hashes on the explorer: the settlement, and the redeem that Somnia validators triggered. Say the number out loud: zero signatures.
6. **2:10–2:30** Autopilot places the next window's call. Activity tape shows the run. Withdraw returns everything.
7. **2:30–2:40** What is next: mainnet, MCP surface so agents can drive a session, richer rules.

Record against testnet. Keep the spare fill clip from Day 3. Prepare a resolved market ahead of recording so beat 5 does not depend on waiting.

---

## 17. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Thin testnet book, IOC never fills | Existential | Spike 1 on Day 1. Own maker script. Disclosed. |
| Binary settlement emits no subscribable event | Existential to the spine | Spike 2 on Day 1. Cut level 3 the same day if it fails. |
| Handler reverts and bricks the subscription | High | Per-market try/catch, caller gate, gas headroom, tests |
| Someone else ships the same consumer wrapper | High | The spine is settlement automation, not UI density. Read every competing BUIDL on Day 1. |
| Indexer lag causes a false Trading state | Medium | Onchain status gate before every send |
| Wrong decimals | Medium | `decimals()` helper used everywhere, asserted in tests |
| Claiming the wrong token id | Medium | Resolve the winner from onchain market state |
| Pool reuse bugs | Medium | `marketId` is the only persisted key |

---

## 18. Claims discipline

Non-negotiable, because it is the fastest way to lose a rubric that rewards verifiable implementation:

- Never state a capability in the README, the video, or the DoraHacks form that is not deployed and running on testnet at submission time.
- Anything designed but not deployed goes in a Roadmap section, in the future tense, and appears nowhere else.
- No hardcoded values standing in for live data anywhere in the submitted build.
- Every claim in the judging map above must map to a verifiable tx hash or a passing test.
- If autopilot is cut, delete every reference to it outside Roadmap, including the video.

---

## 19. Deliverables for DoraHacks

- Working testnet build, live URL
- Public GitHub repo, README a judge can run in three commands
- Source-verified contract addresses on the Shannon explorer
- 2 to 3 minute demo video
- `FEEDBACK.md`: evidence-backed SDK and docs feedback, entries logged as they are hit during the build, not written on Day 7
- Optional: 4-slide deck

---

## 20. Open questions (decide Day 1, do not block)

1. Default market on landing: last visited, or always ETH 15m.
2. Whether direct mode and session mode share one hero card or split.
3. Display P&L in collateral units only (yes for MVP).
4. Whether `/session/[address]` is public read-only (leaning yes, it is a good proof surface).

---

## 21. Decision log

| Date | Decision |
|---|---|
| 2026-09-01 | Ship Pulse, not a generic aggregator or auditor |
| 2026-09-01 | v1 MVP scoped as take-flow plus claim-all plus session tape |
| 2026-09-01 | v2: the spine is reactive settlement. Claim-all becomes an onchain handler, not a browser poller. |
| 2026-09-01 | Session vault holds positions, so no ERC-6909 delegation is required |
| 2026-09-01 | Autopilot is a deterministic user-set rule. No model, no signal, no LLM in the submission. |
| 2026-09-01 | Direct mode is the cut floor and is submittable on its own |
| 2026-09-01 | Liquidity is an owned workstream with a maker script, disclosed in the README |
