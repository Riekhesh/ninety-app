<div align="center">

# NOTCH

**A native iOS health app that ranks you on improvement and consistency — not on absolute numbers.**

*Every fitness app compares you to other people. This one compares you to who you were last month — and ranks you on that.*

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
| **0** | **Foundations & de-risking** | 3–16 Aug 2026 | **in progress** |
| 1 | Single-player core | 17 Aug – 13 Sep | not started |
| 2 | The ranking engine | 14 Sep – 11 Oct | not started |
| 3 | TestFlight & real users | 12 Oct – 8 Nov | not started |
| 4 | Social layer | Nov – Dec | not started |
| 5 | Public launch & iterate | Jan 2027 → | not started |

Phase 0 exists to kill the two things that could sink this project — HealthKit
access and photo-recognition accuracy — in throwaway code, before any real code
gets written. **Live tracker and exit criteria: [`docs/phase-0/`](docs/phase-0/).**

Phases end on a **testable condition, not a date.** If the exit criteria are not
met, the phase is not done.

---

## Repository map

```
docs/
  brief.md                      the source brief, distilled and linkable
  decisions/                    ADRs — every locked decision, with its reversal trigger
  phase-0/                      the live Phase 0 tracker, runbooks and deliverables
    01-prerequisites.md           hardware and toolchain, with a verification script
    02-accounts.md                what to buy and when (dev programme is critical path)
    03-swift-rampup.md            30 days of Swift, mapped onto what Phase 1 needs
    04-competitor-teardown.md     measurement protocol + the numbers + 10 differences
    07-spike-findings.md          results of both spikes, written down
  design/                       the design system: principles, tokens, components, screens
  safety/                       §10 turned into rules with numbers and test names
  security/secrets.md           where every secret lives, and why none is in the app

design/
  tokens/notch.tokens.json      single source of truth for the design system
  tokens/generate.py            → Swift, CSS and a Figma-importable file
  preview/                      the interactive design system page

spikes/                         THROWAWAY. De-risking only — never promoted into the app
  healthkit/                    Spike A — read 30 days of real data on a real device
  vision-accuracy/              Spike B — measure photo-estimate error over 20 real meals

scripts/                        toolchain verification and small helpers
```

Nothing in `Notch/` or `Packages/` yet, deliberately. **Phase 0 is not a build
phase.**

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
