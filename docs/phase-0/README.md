# Phase 0 — Foundations

**3–16 August 2026 · 2 weeks · Objective: kill the risky unknowns before writing any
real code.**

§0.7: *"The purpose of this phase is not to build. It is to make sure that nothing in
weeks 3–16 turns out to be impossible."*

---

## Exit criteria

Phases end on a testable condition, not a date. If these aren't met, the phase isn't
done — extend it and compress a later one.

- [x] **Repo live, SwiftLint configured, secrets handling decided** → `.swiftlint.yml`, [secrets.md](../security/secrets.md)
- [x] **Design tokens, component set, six wireframes, one hero screen** → `design/`, and the [design system page](../../design/preview/design-system.html)
- [x] **Vision cost per image measured** → **$0.000862/image, $1.55/mo at 1,800 calls** — 12–35× under §10's $0.01–0.03 estimate. [Numbers](07-spike-findings.md#cost-per-image--measured-)
- [ ] **Competitor comparison table plus ten deliberate differences** → [04-competitor-teardown.md](04-competitor-teardown.md)
- [ ] **Apple Developer Program membership active** — needed only for the next item
- [ ] **Your own real step and weight history rendering on your own iPhone** → [Spike A](../../spikes/healthkit/README.md)

**Moved out of the exit criteria** (see [ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)):

- **Photo accuracy across 20 weighed meals.** The photo estimate is always presented as
  a helper — ranges, visible uncertainty, one-tap correction — so a bad number changes
  the UX weighting rather than killing the feature. That makes it a **benchmark, not a
  spike**: valuable, but not a gate. Do it during or after Phase 1, whenever the meals
  accumulate. Results still go in [07-spike-findings.md](07-spike-findings.md).

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
Done ────────── Xcode downloaded · GEMINI_API_KEY in .env · cost check measured

Now ─────────── Swift days 1–5

Then ────────── weigh meals as you eat them (slow, passive, no deadline)
                install the 6 teardown apps and just use them
                Swift days 5–20

Then ────────── teardown numbers + 10 differences (~90 min once you've used the apps)
                design the app in Claude (fully unblocked, do it whenever)

Then ────────── buy the dev account → wait for it to clear → Spike A (~90 min)

Then ────────── Phase 1
```

Three things at a time, maximum. Everything else in this repo is reference material —
you do not need to read it to make progress.

---

## Accounts

| Service | Cost | When | Why |
|---|---|---|---|
| **Apple Developer Program** | $99/yr + VAT | **now** | HealthKit, Sign in with Apple, TestFlight. Critical path. |
| GitHub | free | done | Private repo + Actions. Turn on **secret scanning with push protection** in settings. |
| Google Gemini API | pay-as-you-go | **done** | Spike B, using existing credit ([ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)). Measured at $0.000862/image, so the 20-meal baseline is ~$0.02. Anthropic/OpenAI remain optional comparison arms. |
| Supabase | free → ~$25/mo | week 2 | Not needed until Phase 1, but create the project so it exists. |
| PostHog | free | now | Not needed until Phase 3. Create it now so you're not doing admin later (§0.2). |
| Figma | free | optional | Only if you want to mirror the tokens. `notch.tokens.json` imports via Tokens Studio. |

Keys go in `.env` (gitignored) or Supabase Edge Function env vars. Never the app
bundle — see [secrets.md](../security/secrets.md).

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
| `design/tokens/` | `notch.tokens.json` is the single source of truth; `generate.py` emits Swift + CSS and **validates every text/surface pair against WCAG AA**, failing the build on a regression. It caught three real failures in the first draft. |
| `docs/decisions/` | 12 ADRs — the seven locked decisions from §02 plus three new Phase 0 ones |
| `docs/design/` | Principles, component specs, and a full copy deck reviewed against §10 |
| `docs/safety/` | §10 as numbered rules with concrete thresholds and test names. **The numbers need a clinician before Phase 3.** |
| `spikes/` | Both spikes. B is runnable now; A is blocked on the dev account. |

---

## Phase 1 handoff

Once the exit criteria are met, the context primer for a fresh session is in §00 of the
brief. Add to it: the design tokens are generated, not hand-written; the safety rules
in `docs/safety/` are Phase 1 requirements, not Phase 3 polish; and the four things
worth keeping from each spike are listed at the bottom of `HealthSpike.swift` and in
the Spike B README.
