# Claude Design Prompt: Pulse

Copy everything below into Claude. Attach `docs/Pulse-PRD (1).md` and
`docs/README (5).md` in the same conversation. Give Claude access to the two
reference URLs if its environment supports browsing.

---

You are the lead product designer and creative director for **Pulse**, a
consumer-facing onchain trading product being built for the DreamDEX Event
Contracts Hackathon on Somnia. Design the complete responsive product and its
public marketing experience at high fidelity. This is a design assignment, not
an implementation assignment: do not write production code unless I explicitly
ask for it later.

Read the attached PRD and README fully before designing. Treat them as the
source of truth for functionality, terminology, states, and technical claims.
Do not invent capabilities that are not in the documents. If the docs conflict,
follow the PRD and call out the conflict.

## Product in one sentence

Pulse turns a sequence of BTC and ETH Up/Down event-contract windows into one
continuous, capped-risk session: users call the next candle, and Somnia
validators redeem session winnings when the window resolves without another
signature.

The central product idea is:

> One screen. One window. One decision. The rest is automatic.

The central marketing claim is:

> Your winnings come to you.

The most important proof moment is not placing an order. It is showing a market
resolve, then showing the redemption transaction appear with **no signature
required**.

## Audience and tone

Design primarily for repeat crypto traders who understand a directional call
but do not want the density of a professional exchange. It must remain obvious
to a first-time visitor and credible to hackathon judges inspecting whether the
product actually works.

The voice is confident, precise, plain-spoken, and transparent. It is not casino
language, meme trading, or vague Web3 futurism. Use the product vocabulary
consistently: **call, window, stake, payout, Up, Down, session, budget, resolved,
redeemed**. Never use **bet**, **leverage**, or **liquidation** in primary UI.
Never promise profit.

Risk should always be concrete. Example: "Stake 25 tUSDC. You can only lose the
stake." Session limits should lead with the cap: "200 budget · 25 max per
window · 4 windows."

## Reference sites

Study these references before beginning:

- https://tekcify.com/
- https://www.stax.best/

Use Tekcify as a reference for strong editorial rhythm, kinetic product
storytelling, oversized typography, purposeful section transitions, and product
UI embedded into the marketing narrative. Use Stax as a reference for making an
onchain financial product feel understandable, trustworthy, and consumer-ready
through plain copy, clear proof, and polished product mockups.

Do not clone either site. Do not reuse their composition, graphics, colors, or
copy. Pulse must feel like its own product: time-bound, reactive, precise, and
alive. Avoid generic crypto visuals such as glowing coins, token orbits, neon
planet imagery, random grids, and meaningless chain diagrams.

## Creative direction

Create a dark, dense, high-trust financial interface built around the visual
language of a live time window. The countdown is the primary object, not a small
label. Time, state change, and settlement should shape the identity.

Start from deep ink/navy rather than pure black. Use restrained green for Up and
positive/settled states, restrained red for Down and danger/expiry states, and a
cool neutral or signal color for Somnia/reactive-system events. Up and Down must
have equal visual authority; the brand cannot look permanently bullish.

Use **Space Grotesk** or a similarly distinctive grotesk for display and product
headings, and **JetBrains Mono** or an equivalent technical mono for prices,
countdowns, market IDs, transaction hashes, and compact labels. Body copy must
remain highly readable. Define an explicit type scale, spacing system, color
tokens, radii, borders, shadows, and icon style.

Build one memorable signature device from the product itself: a **living window
rail** or **pulse timeline** that progresses from Trading → Locked → Resolved →
Redeemed → Next window. It should appear in both marketing storytelling and the
product UI, adapting from expressive to compact. Spend the visual boldness here
and keep surrounding elements disciplined.

The design should feel active without becoming noisy. Prefer one orchestrated
motion system over scattered effects. Consider countdown ticks, a lock-state
transition, a settlement pulse travelling through the rail, and an activity row
appearing as "no signature required." Specify reduced-motion alternatives.

Avoid these common AI-design defaults:

- Purple-on-black gradients as the primary identity
- Glassmorphism on every surface
- Giant empty heroes with decorative blobs
- Inter or system fonts without a reason
- Repeated generic card grids
- Fake charts, fake testimonials, fake TVL, fake partner logos, or fake metrics
- Overusing pills, gradients, glow, and rounded containers
- Hiding important trading information to make the interface look minimal

## Information architecture

Design these distinct destinations and show how navigation behaves before and
after wallet connection:

1. `/` — marketing landing page for visitors, with a live/read-only active ETH
   15m window embedded in the hero and a clear path into the app.
2. `/app` — focused trading home: active window, action controls, session state,
   mini book, current position, and next-window teaser.
3. `/markets` — all live BTC/ETH 15m and 1h windows, with useful filtering and
   clear status/countdown hierarchy.
4. `/market/[marketId]` — one market deep link with full decision context,
   position, order state, compact book, and transaction history.
5. `/positions` — wallet-held and session-held positions across Open, Locked,
   Unclaimed, and Claimed states.
6. `/activity` — reverse-chronological tape of placed, filled, cancelled, locked,
   resolved, auto-claimed, auto-rolled, and withdrawn events.
7. `/session/new` — session setup flow for budget, maximum stake, window count,
   allowed pair/duration, expiry, and deterministic rule.
8. `/session/[address]` — public, read-only proof page showing policy, session
   balance, window history, settlement/redemption transaction pair, and which
   actions required no signature.
9. A claim-all sheet for direct mode and a withdrawal sheet for session mode.
10. Supporting marketing/legal pages or sections: How it works, Security &
    control, FAQ, Docs/GitHub links, testnet disclosure, footer, privacy, and
    terms. Keep these appropriately scoped for a hackathon MVP.

The marketing site and app must share one identity but differ in density. The
marketing page explains and dramatizes. The app compresses and prioritizes.

## Landing page narrative

Design the landing page as a coherent story, not a stack of interchangeable
sections. Include:

1. A compact navigation with Pulse identity, How it works, Security, GitHub or
   Docs, network status, and an **Open app** CTA.
2. A hero whose thesis is the live window itself. Pair "Your winnings come to
   you" with an active read-only ETH 15m module showing strike, countdown, Up and
   Down prices, and a credible product preview. Do not require wallet connection
   to understand the product.
3. A concise problem section showing how winnings become scattered across
   resolved windows when users must redeem each one manually.
4. The signature pulse timeline showing **Call → Lock → Resolve → Redeem → Roll**.
   Make the no-signature redemption the visual climax.
5. A product section explaining the two modes: Direct mode keeps positions in
   the user's wallet and offers Claim all; Session mode uses a user-owned policy
   vault for validator-triggered redemption.
6. A session-policy demonstration using a realistic example: 200 tUSDC budget,
   25 maximum per window, 4 ETH 15m windows, stops after one miss. Show that the
   user can disarm or withdraw at any time.
7. A trust/proof section: self-controlled funds, onchain-enforced limits,
   withdrawals never locked, every action linked to an explorer transaction,
   no keeper bot, and no browser tab required. Phrase only what the attached
   product documents support.
8. An activity-tape moment pairing the market settlement transaction with the
   reactive redemption transaction and the label **No signature required**.
9. An accessible FAQ using real objections from the PRD: What is an event
   contract? What can I lose? Who holds my funds? Can I withdraw anytime? What
   happens when a market is voided? What does autopilot decide? Why testnet?
10. A final CTA that returns to the live-window decision, plus a compact footer
    with Somnia, DreamDEX, testnet, GitHub, docs, terms, privacy, and risk copy.

Do not include invented testimonials, customer logos, volume numbers, or
performance statistics. Technical proof is the social proof for this product.

## Core app screen

The app should make the active window comprehensible in under five seconds.
Design the hierarchy around:

- Pair and duration: ETH · 15m
- Status: Trading / Locked / Resolved / Voided
- Large UTC-anchored countdown, turning urgent below 60 seconds without relying
  on color alone
- Strike/open price
- Up probability and derived Down probability
- Stake presets: 10, 25, 50, 100, plus custom
- Two clear action buttons: **Call Up** and **Call Down**
- Pre-confirmation math: stake, maximum loss, effective contracts, payout basis
- Top-of-book depth in Up terms
- User position for this window
- Next-window teaser as the current window nears its end
- Wallet balance, network, claim badge, and active-session indicator

Direct and Session mode should feel like modes of the same instrument, not two
separate products. Show how the hero card changes when a session is armed:
budget remaining, windows remaining, policy in one plain sentence, and persistent
Disarm and Withdraw actions.

## States and interaction coverage

Design complete component states, not only the ideal screenshot:

- Disconnected wallet and read-only live market
- Wallet connecting, wrong network, and network switching
- Zero tUSDC balance with a clear faucet path
- Loading, stale/indexer lag, disconnected stream, and retry
- Trading, under-60-second urgency, Locked, Resolved, and Voided
- Up selected, Down selected, size selected, custom size, validation error
- Confirming in wallet, transaction pending, full fill, partial fill, missed IOC,
  rejected transaction, decoded contract error, and cancelled residual order
- No position, open position, locked position, winning/losing result, redeemable,
  claimed, and void payout
- No session, creating/deploying, funding, armed, disarmed, expired, max windows
  reached, withdrawing, and withdrawn
- Empty activity and positions views
- Claim-all success, partial success with per-market error isolation, and failure
- Settlement and redemption explorer links
- Skeleton, empty, error, and offline behavior at page and component levels

Show concise copy for important errors and empty states. Never display a bare
"execution reverted." Explain what happened and the next available action.

## Responsive and accessibility requirements

Produce desktop, tablet, and mobile designs for the landing page and core app.
The app must work at 360px width without turning into an unreadable desktop table.
On mobile, keep the active decision and countdown visible, use a deliberate
bottom action region where appropriate, and move secondary depth/history into
drawers or segmented views without hiding risk and payout information.

Meet WCAG AA contrast. Do not communicate Up/Down or status by color alone; use
labels, icons, and shape. Define visible keyboard focus, logical tab order,
44px-minimum touch targets, screen-reader names, number formatting, and reduced
motion. Include keyboard ideas from the PRD only as optional enhancement: U/D for
side and 1/2/3 for presets.

## Deliverables

Work in these stages and show the reasoning briefly:

1. **Product synthesis:** summarize the user, core job, key proof, and constraints
   you extracted from the PRD. List any assumptions separately.
2. **Three art directions:** provide three genuinely different visual concepts,
   each with a name, rationale, palette, typography, layout behavior, signature
   device, and motion idea. Avoid three superficial color variants.
3. **Recommendation:** choose one direction and explain why it best serves Pulse.
   Critique it for generic AI-design patterns and revise anything that feels
   interchangeable with another crypto product.
4. **Sitemap and flows:** map the full page set, global navigation, first trade,
   open session, automatic settlement, claim-all, and withdrawal journeys.
5. **Low-fidelity structure:** create desktop and mobile wireframes for the
   landing page, core app, market detail, session setup, and public session proof.
6. **Design system:** provide named colors with hex values, type families and
   scale, spacing, grid, radii, borders, elevation, icon rules, data formatting,
   state colors, and reusable component inventory.
7. **High-fidelity pages:** design every route in the information architecture,
   including responsive variants and the critical states listed above.
8. **Prototype:** connect at least these moments: landing → app, select side and
   stake → confirm, start session → review policy → armed session, resolving
   window → no-signature redemption, claim-all, and withdraw.
9. **Handoff:** provide component annotations, interaction behavior, responsive
   rules, motion timings/easing, content/copy sheet, token export, and asset list
   so a Next.js/Tailwind engineer can implement without guessing.
10. **Final audit:** check product accuracy against the PRD, claim discipline,
    state completeness, accessibility, mobile usability, copy consistency, and
    visual distinctiveness. Explicitly list anything still unresolved.

Use realistic product data, not lorem ipsum: ETH 15m, 08:42 remaining, strike
$3,842.16, Up 0.57, Down 0.43, 25 tUSDC stake, 43.86 contracts, 200 tUSDC session
budget, 4 windows, and shortened transaction hashes. Clearly label sample data
as sample design content, not live performance.

Do not stop after a moodboard or landing page. The assignment is complete only
when the marketing site, full product route set, responsive behavior, component
system, major transaction states, and developer handoff are all designed as one
coherent experience.

Before starting, confirm that you have read both attached documents and the two
reference sites. Then begin with product synthesis and the three art directions.

