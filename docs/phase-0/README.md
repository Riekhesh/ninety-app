# Phase 0 — Foundations

**3–16 August 2026, closed 31 August · Objective: kill the risky unknowns before
writing any real code.**

> ## ✅ PHASE 0 IS CLOSED
>
> Every exit criterion is met. The last — HealthKit on a real device — passed on
> 31 August, three weeks past the nominal window, effectively all of it spent waiting
> on the Apple Developer enrolment that gates it. Phases end on a testable condition
> and not a date; the condition is met, so the phase is done.
>
> **Nothing in this project can now turn out to be impossible.** That was the whole
> objective.

§0.7: *"The purpose of this phase is not to build. It is to make sure that nothing in
weeks 3–16 turns out to be impossible."*

---

## Exit criteria

Phases end on a testable condition, not a date. If these aren't met, the phase isn't
done — extend it and compress a later one.

- [x] **Repo live, SwiftLint configured, secrets handling decided** → `.swiftlint.yml`, [secrets.md](../security/secrets.md)
- [x] **Design tokens, component set, six wireframes, one hero screen** → `design/`, and the [design system page](../../design/preview/design-system.html)
- [x] **Vision cost per image measured** → **$0.000862/image, $1.55/mo at 1,800 calls** — 12–35× under §10's $0.01–0.03 estimate. [Numbers](07-spike-findings.md#cost-per-image--measured-)
- [x] **Competitor comparison table plus ten deliberate differences** → [04-competitor-teardown.md](04-competitor-teardown.md). Closed on desk research + prior hands-on use; **tap counts deliberately not measured** ([scope decision](04-competitor-teardown.md#scope-decision--closed-without-tap-counts)). The teardown's one finding that changed the project — Strava already rewards pace-agnostic consistency — is settled in [ADR 0013](../decisions/0013-narrowed-thesis-claim.md) and the narrowed wording is now live in the README, the design system page and the design brief.
- [x] **Apple Developer Program membership active** — approved 2026-08-30. It existed only to unblock the next item
- [x] **Your own real step and weight history rendering on your own iPhone** → **passed 2026-08-31**, iPhone on iOS 26.6.1. 31 days of steps, plus weight, active energy, exercise minutes and workouts. [Numbers and findings](07-spike-findings.md#spike-a--healthkit--measured-)

**Moved out of the exit criteria** (see [ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)):

- **Photo accuracy across 20 weighed meals.** The photo estimate is always presented as
  a helper — ranges, visible uncertainty, one-tap correction — so a bad number changes
  the UX weighting rather than killing the feature. That makes it a **benchmark, not a
  spike**: valuable, but not a gate. **Folded into Phase 1** (decided 2026-08-30) —
  its exit criteria already require 21 days of logged food, so the meals arrive from
  real use rather than a separate evening's collection. Requires only that Phase 1's
  logging keeps the photo alongside the confirmed values. Results still go in
  [07-spike-findings.md](07-spike-findings.md).

---

## Spike vs benchmark — the distinction that decides urgency

| | Question | If the answer is bad | Urgency |
|---|---|---|---|
| **Spike A · HealthKit** | *Can I get weight and step data off my iPhone at all?* | **The project dies.** No UX rescues it. | Real gate |
| **Cost per image** | *What does one photo estimate cost?* | Surprise bill with real users (§10) | ✅ **Done** — $0.000862 |
| **Accuracy benchmark** | *How wrong is the estimate?* | Correction becomes the primary interaction instead of a secondary one | Whenever |

A **spike** can kill a feature. A **benchmark** calibrates one. Only the first is a gate.

---

## Sequencing

The Apple Developer Program is $99 + VAT and its *only* purpose is unblocking Spike A.
Enrolment takes several days, so buy it about a week before you want to run Spike A —
not on day one, where it sits unused while you learn Swift.

This is a deliberate deviation from §0.1, which puts the purchase in week one. §0.1
assumes you are ready to build immediately; the account should arrive just before the
thing it unblocks.

```
Done ────────── Xcode · GEMINI_API_KEY in .env · cost check measured
                thesis narrowed (ADR 0013) · harness refuses unpriced models
                Supabase live (PostHog deferred to Phase 3)
                Swift ramp-up — 100 Days of SwiftUI, days 1–30
                design — Matchday, six screens, palette in the tokens
                dev account APPROVED

                SPIKE A PASSED — 56,764 → 0 on the anchor test

Now ─────────── PHASE 1. Single-player core.
                First design task: fixed type scale vs Dynamic Type
                First build rule: HKStatisticsCollectionQuery, never raw samples

Passive ─────── send the clinician pack (a Phase 3 gate, not this one)
                the accuracy benchmark accumulates during Phase 1's 21 days
```

**Phase 0 delivered what it was for.** Two findings that change the build, both
measured rather than assumed: HealthKit stores ~1,830 step samples *per day*, so daily
totals must be bucketed inside HealthKit; and a denied read is indistinguishable from
no data, so there is no permission-denied branch to write.

**Spike A is the last criterion and the one that can still kill the project** — if a
real device will not hand over weight and steps, no amount of design rescues it.
Everything else in Phase 0 is closed.

**The two remaining exit criteria are both downstream of Apple**, and nothing else in
this phase is. Everything under *Now* is work the enrolment wait does not block — which
is the point of doing it during the wait rather than after it.

Three things at a time, maximum. Everything else in this repo is reference material —
you do not need to read it to make progress.

---

## Accounts

| Service | Cost | When | Why |
|---|---|---|---|
| **Apple Developer Program** | $99/yr + VAT | **purchased — awaiting enrolment** | HealthKit, Sign in with Apple, TestFlight. Critical path. |
| GitHub | free | done | Private repo + Actions. Turn on **secret scanning with push protection** in settings. |
| Google Gemini API | pay-as-you-go | **done** | Spike B, using existing credit ([ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)). Measured at $0.000862/image, so the 20-meal baseline is ~$0.02. Anthropic/OpenAI remain optional comparison arms. |
| Supabase | free → ~$25/mo | week 2 | Not needed until Phase 1, but create the project so it exists. Click-path: [accounts.md](accounts.md) |
| PostHog | free | now | Not needed until Phase 3. Create it now so you're not doing admin later (§0.2). Click-path: [accounts.md](accounts.md) |
| Figma | free | optional | Only if you want to mirror the tokens. `ninety.tokens.json` imports via Tokens Studio. |

Keys go in `.env` (gitignored) or Supabase Edge Function env vars. Never the app
bundle — see [secrets.md](../security/secrets.md).

Click-path for the two that are still outstanding: **[accounts.md](accounts.md)**,
~25 minutes for both. Then `scripts/verify-accounts.sh`, which is the testable
condition — it checks every value is present and the right shape, and never prints one.

---

## Toolchain

You have the Mac and the iPhone. Verify the rest:

```bash
scripts/verify-toolchain.sh
```

| Requirement | Why |
|---|---|
| macOS Tahoe 26.2+ | Xcode 26.6's hard floor |
| Xcode 26.6 stable | Bundles Swift 6.3. **Not** the Xcode 27 beta for a project you intend to ship (§04) |
| ~40 GB free | Xcode + simulators. A real constraint on a 256 GB machine |
| iPhone on iOS 18+ | HealthKit does not meaningfully work in the Simulator |
| Deployment target iOS 18.0 | [ADR 0002](../decisions/0002-ios-18-deployment-target.md) |
| `brew install swiftlint` | Configured already; nothing to fix yet, which is the point |

---

## Swift ramp-up

You're new to Swift. §0.3 is emphatic about the trap: *"Finishing a 100-day course
before writing your own first line is the most common way this project quietly dies in
September. You need enough Swift to be dangerous, not enough to be comfortable."*

**Work days 1–30 of [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui)
concurrently with this phase, then learn the rest by building.** Roughly an hour a
day. Do not wait until you've finished.

> **Done.** Days 1–30 complete. The list below is now a *reference* for Phase 1 rather
> than a plan — when something in Phase 1 doesn't behave, it is most often one of
> these five, in this order.

What Phase 1 actually needs from those 30 days, in priority order:

1. **Optionals and `if let` / `guard let`** — the single biggest source of beginner
   crashes, and why `force_unwrap` is a lint warning in this repo
2. **`async`/`await`** — every HealthKit and Supabase call. Days ~15–20
3. **`struct` vs `class`, and value semantics** — why SwiftUI state behaves as it does
4. **Protocols** — the whole repository pattern depends on them ([ADR 0004](../decisions/0004-mvvm-observation-not-tca.md))
5. **SwiftUI state: `@State`, `@Binding`, `@Observable`** — days ~20–30

Three things the course won't cover that you'll need, and where they're already written
down for you:

- **`@Observable`** (not `ObservableObject`) — the iOS 17+ pattern. Example in
  `spikes/healthkit/HealthSpike.swift`
- **HealthKit anchored queries** — the whole of Spike A
- **Swift 6 strict concurrency** — `@MainActor`, `Sendable`. Also in the spike

Skip for now: Core Data (we use SwiftData), UIKit, Combine.

---

## What was already done here

Committed in this phase, so you don't have to redo it:

| | |
|---|---|
| `.swiftlint.yml` | Standard rules **plus custom rules that enforce brief decisions**: RankingEngine purity (no UI imports, no ambient clock, no randomness — [ADR 0006](../decisions/0006-ranking-engine-client-side-first.md)), no hardcoded colours, no punishment framing in strings (§10), no embedded secrets |
| `.githooks/` | Secret + health-data tripwires, token-sync check, conventional-commit enforcement. Enable with `git config core.hooksPath .githooks` |
| `design/tokens/` | `ninety.tokens.json` is the single source of truth; `generate.py` emits Swift + CSS and **validates every text/surface pair against WCAG AA**, failing the build on a regression. It caught three real failures in the first draft. |
| `docs/decisions/` | 12 ADRs — the seven locked decisions from §02 plus three new Phase 0 ones |
| `design/spec/` | Principles, component specs, and a full copy deck reviewed against §10 |
| `docs/safety/` | §10 as numbered rules with concrete thresholds and test names. **The numbers need a clinician before Phase 3** — [clinician-review-pack.md](../safety/clinician-review-pack.md) is the self-contained ~30-minute document to send them, and [who to ask](../safety/safety-requirements.md#the-pack-to-send-them) is written down. |
| `spikes/` | Both spikes. B is runnable now; A is blocked on the dev account. |

---

## Phase 1 handoff

Once the exit criteria are met, the context primer for a fresh session is in §00 of the
brief. Add to it: the design tokens are generated, not hand-written; the safety rules
in `docs/safety/` are Phase 1 requirements, not Phase 3 polish; and the four things
worth keeping from each spike are listed at the bottom of `HealthSpike.swift` and in
the Spike B README.
