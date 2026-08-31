<div align="center">

# NOTCH

**A native iOS health app that ranks you on improvement and consistency — not on absolute numbers.**

*Consistency is a side badge wherever it exists. Here it is the rank — and it is normalised, so a 120 kg beginner and a 70 kg regular can be compared fairly.*

`Swift 6.3` · `SwiftUI` · `iOS 18+` · `Supabase` · TestFlight target **Nov 2026**

</div>

---

## The thesis

Absolute leaderboards punish exactly the people who most need a fitness app. Post a
12-minute mile on Strava and you are buried under people running sixes. Someone
25 kg overweight will never top a "heaviest bench" board. The people with the
furthest to go get the least encouragement, and they quit first.

**Rate of improvement and consistency are things a total beginner can genuinely win
at** — and they are also the two variables that most strongly predict long-term
weight-loss outcomes. The product design and the underlying science point the same
way, which is rare and worth building the whole app around.

### What this claim is *not* — tested in Phase 0

It is not *"nobody rewards consistency."* They do. Strava's
[Local Legend](https://support.strava.com/en-us/articles/15401751-local-legends) crowns
whoever runs a segment **most often over 90 days, regardless of pace** — a ranking a slow
beginner can genuinely top. The Phase 0 teardown went looking for that counter-example
and found it, so the claim is stated narrowly on purpose ([ADR 0013](docs/decisions/0013-narrowed-thesis-claim.md)):

| | Strava Local Legend | Notch |
|---|---|---|
| Rewards | raw **frequency** on one segment | **improvement rate + consistency** |
| Normalised for starting point? | **No** | **Yes** — DOTS/Wilks-style coefficient (§2.2) |
| Scope | one segment you chose | your whole logged behaviour |
| Is it the headline? | no — the fastest time is | **yes — it *is* the rank** |

Consistency is a **side badge** everywhere it exists today. Making normalised
improvement the rank itself is the part nobody has done, and normalising across starting
points is the part §01 correctly calls the hard engineering problem. Local Legend is
cited as prior art here the way §01 already cites Wilks and DOTS —
[the full check](docs/phase-0/04-competitor-teardown.md#strava--the-thesis-check).

The app is not the hard part; calorie loggers are a solved problem. The hard part is
a rating system that is simultaneously **fair across starting points**, **resistant
to sandbagging**, and **robust to self-reported garbage**. That system is the
project. Everything else exists to feed it data.

> **This sentence is the scope filter.** If a feature cannot be traced back to it, it
> does not go in v1.

---

## Where the project is

| Phase | What it is | Window | Status |
|---|---|---|---|
| **0** | Foundations & de-risking | 3–31 Aug 2026 | ✅ **closed** |
| **1** | **Single-player core** | from 31 Aug | **in progress** |
| 2 | The ranking engine | 14 Sep – 11 Oct | not started |
| 3 | TestFlight & real users | 12 Oct – 8 Nov | not started |
| 4 | Social layer | Nov – Dec | not started |
| 5 | Public launch & iterate | Jan 2027 → | not started |

Phase 0 existed to kill the risky unknowns in throwaway code, before any real code got
written. **It closed on 31 August with every exit criterion met**, and what it found:

- **Vision cost — $0.000862/image, $1.55/mo** at §10's volumes. 12–35× under the
  brief's estimate, so cost is not the constraint it was assumed to be.
- **HealthKit works**, on a real device, and it was the one unknown that could have
  ended the project. It also produced the two findings that shape Phase 1: HealthKit
  stores **~1,830 step samples per day**, so daily totals must be bucketed inside
  HealthKit rather than iterated; and **a denied read is indistinguishable from no
  data**, so there is no permission-denied branch to write.
- **The thesis narrowed.** Strava already rewards pace-agnostic consistency, so the
  claim is now the sharper one ([ADR 0013](docs/decisions/0013-narrowed-thesis-claim.md)).
- **Photo accuracy is a benchmark, not a gate** ([ADR 0010](docs/decisions/0010-anthropic-as-vision-provider.md)) —
  the estimate is always a helper with one-tap correction.

**Numbers: [`07-spike-findings.md`](docs/phase-0/07-spike-findings.md) · closed tracker: [`docs/phase-0/`](docs/phase-0/).**

Phases end on a **testable condition, not a date.** If the exit criteria are not
met, the phase is not done.

---

## Repository map

```
docs/
  decisions/                    ADRs — every locked decision, with its reversal trigger
  phase-0/
    README.md                     the live tracker: exit criteria, critical path, accounts
    04-competitor-teardown.md     measurement protocol + the numbers + 10 differences
    07-spike-findings.md          results of both spikes, written down
  safety/                       §10 turned into rules with numbers and test names
  security/secrets.md           where every secret lives, and why none is in the app

design/                         ONE design tree — values, specs and preview together
  tokens/notch.tokens.json      single source of truth for the design system
  tokens/generate.py            → Swift + CSS + the chat brief; validates WCAG AA
  generated/                    DO NOT EDIT — regenerate from the tokens
  spec/                         principles, components, and the copy deck
  preview/design-system.html    the interactive design system page

spikes/                         THROWAWAY. De-risking only — never promoted into the app
  healthkit/                    Spike A — read 30 days of real data on a real device
  vision-accuracy/              cost per image (done) + the 20-meal accuracy benchmark

scripts/                        verify-toolchain.sh (the Mac) · verify-accounts.sh (.env)
```

**[`CLAUDE.md`](CLAUDE.md) is the routing table** — which file answers which question,
so neither you nor an agent reads twelve to find two.

The brief itself is not in the repo — it is the source PDF. Its locked decisions are
in [`docs/decisions/`](docs/decisions/), and every doc here cites the section it came
from (`§0.7`, `§2.3`) so a claim can be traced back.

Nothing in `Notch/` or `Packages/` yet — Phase 0 was not a build phase. Phase 1 is,
and creates them.

---

## Architecture, in one screen

```
Views (SwiftUI)
  ↓
ViewModels (@Observable)
  ↓
Repositories (protocol-based)  ← inject mocks here for testing
  ↓
SwiftData (local, source of truth) · Supabase (remote) · HealthKit (device)

RankingEngine — standalone Swift Package. Pure functions. No I/O, no UI imports.
```

Two decisions carry most of the weight:

**Offline-first is non-negotiable.** Gyms have no signal. Restaurant basements have
no signal. If logging fails offline, the user learns the app is unreliable at exactly
the moment they were building a habit. SwiftData is the local source of truth, an
outbox table holds pending mutations, and a sync service drains it when connectivity
returns. Last-write-wins on server timestamps for v1 — the limitation is documented
rather than solved with CRDTs.

**The ranking engine is isolated on purpose.** Client-side scoring is fine while the
only competitor is your past self. The moment leaderboards exist it must move
server-side, because a client-authoritative score is trivially cheatable with a
patched binary. Keeping the engine pure and deterministic, with test vectors that
will validate an identical server port, is what makes that migration a port rather
than a rewrite. It is the hard gate on Phase 4.

---

## Getting set up

```bash
git clone git@github.com:Riekhesh/Notch-App.git
cd Notch-App

git config core.hooksPath .githooks   # secret + lint + commit-message hooks
cp .env.example .env                  # then fill it in; .env is gitignored

scripts/verify-toolchain.sh           # checks macOS, Xcode, disk, device, CLI tools
brew install swiftlint
```

**Read [`docs/security/secrets.md`](docs/security/secrets.md) before you touch a
key.** The short version: no API key ever enters the app bundle or this repo, and
because Supabase's anon key is public by design, Row-Level Security is the *only*
thing protecting user health data — not a defence-in-depth nicety.

---

## Working on the design

The token system is real code: `design/tokens/notch.tokens.json` is the single source
of truth, and `python3 design/tokens/generate.py` emits the Swift and CSS **and fails
the build if any text-on-surface pair drops below WCAG AA**. It caught three genuine
contrast failures in its first run.

To iterate on screens conversationally, paste
[`design/generated/claude-design-brief.md`](design/generated/claude-design-brief.md) into a
fresh Claude chat — it's a compact, self-contained version of the tokens, the seven
rules, the copy rules and all six screens. Bring anything you land back into the
tokens file and regenerate.

---

## Safety is a build requirement, not a launch checklist

A gamified calorie app with streaks and competitive ranks can actively reinforce
disordered eating. This is a real, documented harm; Apple has rejected apps over it;
and there will be real users who are vulnerable in ways no dashboard will show.

Six requirements are built in **from Phase 1**, not bolted on: a hard minimum
calorie floor, goal-weight validation against healthy BMI, an age gate, no
punishment framing anywhere, an always-available switch that disables every
competitive feature without breaking the app's core usefulness, and a **rate-of-loss
ceiling in the scoring engine** so that losing weight faster than a safe rate is not
rewarded.

That last one is the neat part: the ranking design and the safety design happen to
want exactly the same thing. Scoring the *appropriate* rate highest rather than the
maximum is both safer and a better model of real progress.

Full spec with numbers and test names: [`docs/safety/`](docs/safety/).

---

## Contributing

Solo project, but the conventions are real — the git history is a portfolio artifact.
Conventional commits, enforced by a hook. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).

---

<div align="center">
<sub>

Not a medical device. Notch makes no medical claims and is not a substitute for
professional advice.

</sub>
</div>
