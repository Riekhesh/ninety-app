# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Native Swift 6.3 / SwiftUI, iOS 18+ deployment target (ADR 0001, 0002). Backend is
Supabase (ADR 0003). **Design deliverables in Phase 0 are HTML artboards at 393×852**
(iPhone-frame mockups); the build target is SwiftUI, bridged through
`design/tokens/notch.tokens.json` → `generate.py` → `DesignTokens.generated.swift`.
SwiftLint bans hardcoded colours in Swift at error severity, so a palette that is not
in the tokens file cannot ship.

## Users

One user today (the developer, UK, building it as a final-year portfolio project);
~20 friends-and-family TestFlight testers in Phase 3; possible public App Store launch
after. The core intended user is a **beginner with a lot of weight to lose** — the
person absolute leaderboards bury. Usage scene: quick daily interactions on a phone —
log a meal in seconds, glance at today's numbers, check the weekly rank.

## Product Purpose

A calorie + weight tracker whose distinguishing feature is the **ranking engine**: it
ranks the user on normalised rate-of-improvement and consistency, not absolute
numbers. Logging exists to feed the engine; the engine is the product (brief §07).
Success = the user keeps logging (consistency is 0.50 of the score) and the weekly
rank feels earned and fair.

## Positioning

"Consistency is a side badge everywhere it exists; here it **is** the rank, and it is
normalised so a 120 kg beginner and a 70 kg regular can be compared fairly." (ADR 0013
— deliberately narrowed; Strava Local Legend is cited as prior art, not ignored.)
Nobody has made normalised improvement the headline ranking itself.

## Phase state

**Phase 0 closed 31 August 2026.** Every exit criterion met. Two findings from it bind
Phase 1's build and are not negotiable:

- **Never iterate raw HealthKit samples for a daily total.** Measured: ~1,830 step
  samples and ~3,000 active-energy samples *per day*. Use
  `HKStatisticsCollectionQuery`, which buckets inside HealthKit.
- **There is no permission-denied branch to write.** A denied read returns an empty
  result identical to "no data"; iOS will not distinguish them. Every data surface
  needs a designed empty state whose wording covers both.

**Phase 1 (single-player core) is in progress.** Its first design decision is the open
one below; its exit criteria include 21 days of logged food, which is also where the
photo-accuracy benchmark's data comes from.

## Operating Context

- Weekly score computed from logged food, weight trend (HealthKit), and consistency.
- Tiers: bronze → silver → gold → platinum → diamond, fixed thresholds in v1 (ADR 0007).
- First 14 days = calibration window ("CALIBRATING · N days to go"), no rank shown.
- Photo → calorie estimation is a helper with mandatory confirm/correct — never
  silently accepted (ADR 0010).
- MVP surface set (6 screens): Onboarding (goal & rate), Today, Log food, Photo
  confirm & correct, Weight & trend, Rank (the hero / App Store screenshot).

## Capabilities and Constraints

**Safety constraints — load-bearing, enforced by lint + tests, not taste
(docs/safety/safety-requirements.md):**

- 17 banned punishment phrases at lint-error severity (S5). No "you broke/failed/
  missed" framing anywhere; regression is a reset, and losing a tier always states
  the way back.
- **No error colour for logged intake.** Going over your band is not an error; the
  token set deliberately has no red for it. `critical` is destructive-confirm only;
  `safety` is reserved for §10 interventions (calorie floor, rate ceiling).
- A missed day renders **empty, never crossed out**. No streak-loss animation.
- **No confetti / rate-rewarding celebration** — the engine caps rate of loss for
  safety (S3); celebration of speed would fight it.
- Tier must be readable **without colour alone** (ADR 0012 — silver/gold differ by
  1.14:1). Currently carried by notch count; any replacement must carry an equally
  colour-independent channel.
- Rank breakdown shows its **weights visibly** (CONSISTENCY 0.50 / ADHERENCE 0.25 /
  PROGRESS 0.25). No other user's name or number anywhere in v1; no percentile.
- Calorie target is always a **band, not a single number** ("1,750–1,950").

**Technical constraints:**

- Every screen fits a 393×852 viewport without scrolling (Today's list may scroll
  below the fold, but the layout's spine must land inside it).
- **Open decision, still undecided after the redesign:** fixed type scale (current
  tokens) vs Dynamic Type (ios.md requires system text styles and bans hard-coded
  point sizes). The mockups use the fixed scale because an artboard cannot express
  Dynamic Type; the SwiftUI build must pick one. Deciding it is Phase 1's first
  design task, and it is the one thing in the redesign that a 393×852 mockup could
  not settle.

## Brand Commitments

- Name: **Notch**. The notch-count tier encoding is a *cool concept* the user is open
  to keeping, but the current literal execution (badge = rounded rect with notches)
  is judged too basic; the logo/badge may be reinvented as long as the
  colour-independent tier channel survives.
- Dark-first, light parity later (ADR 0011 — direction locked, palette values not).
- Voice: calm, factual, never punitive. Copy deck at design/spec/04-copy-deck.md.
- **Visual world chosen 2026-08-30: MATCHDAY** — a lit football pitch, not a dark app
  with green paint. Deep pitch green, mown stripes, a floodlight thrown from the
  top-left, 2px chalk lines, one gold reserved for the division. Kit stripes are the
  club device. The product language is football throughout: Matchday (the day), Sub On
  (logging), The Table (rank), The Squad / On the Bench (frequent / recent foods),
  First & Second Half (meal periods), Form (7-day consistency), Divisions (tiers,
  chevrons carrying the count). Two directions were built and cut: Gauge (dark
  instrument) and Split-Flap (departure board).
- **Tier = division**, carried by chevron count and the word, never colour alone.
- **The calorie range renders as a single figure plus tolerance** (`612 ±100`), never
  as two numbers joined by a dash.

## Evidence on Hand

- Real data for mockups (use these, never lorem/round numbers): band 1,750–1,950;
  remaining 512–712; 1,238 logged; weight 78.4 kg, −1.2 kg vs 4 wks; days logged
  5/7; composite 0.71; CONSISTENCY 0.50 → 0.86, ADHERENCE 0.25 → 0.71, PROGRESS
  0.25 → 0.52; "Gold holds at 0.65"; week of 3 August; meals: flat white 120,
  chicken salad bowl 545, greek yogurt & berries 233.
- Measured: vision cost $0.000862/image. No accuracy baseline yet — do not invent one.
- No testimonials, no user metrics, no press. Do not fabricate.

## Product Principles

1. **The engine is the product.** Every surface exists to feed or express the weekly
   score; features that don't trace to the rank don't ship (brief scope filter).
2. **Fair beats flattering.** Normalisation and visible weights over vanity metrics;
   honesty markers (bands, ranges, confidence) over false precision.
3. **Safety outranks retention.** The proven mechanics that §10 bans (loss-aversion
   streaks, punishment framing, speed rewards) stay banned even though they work.
4. **The correction is one tap.** Estimates are helpers; the user is the authority.
5. **Consistency must feel like the headline**, not a side stat — that is the thesis.

## Accessibility & Inclusion

- WCAG AA contrast enforced mechanically by design/tokens/generate.py (refuses
  failing pairs at build time).
- Tier state never carried by colour alone (ADR 0012).
- Dynamic Type support is the open decision noted above; whatever the redesign
  chooses must be recorded and carried into Phase 1.
