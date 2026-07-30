# ADR 0006 — Ship the ranking engine client-side first, as a pure package

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §2.1, §09

## Context

The ranking engine is the differentiator. It is also the only thing in the app that is
worth cheating at.

Through Phases 1–3 the only competitor is the user's past self, so a wrong or
manipulated score harms nobody but the person who manipulated it. The moment friend
leaderboards exist in Phase 4, that stops being true.

## Decision

`RankingEngine` is a **standalone Swift Package**: pure functions, no I/O, no
`SwiftUI`/`UIKit`/`SwiftData`/`HealthKit`/network imports, no ambient clock, no
randomness. Data in, score out.

It runs **client-side** through Phase 3.

**It must move server-side before any leaderboard ships.** This is the hard gate on
Phase 4 — not after, not alongside.

## Trade-off accepted

A client-authoritative score is trivially cheatable with a patched binary. That is
knowingly accepted for Phases 1–3 in exchange for zero latency, full offline
operation, and a dramatically simpler build.

The migration is deferred work, not avoided work, and it is real work.

## Why the purity constraints are load-bearing, not stylistic

The three lint rules in `.swiftlint.yml` that guard this package
(`ranking_engine_no_ui_imports`, `ranking_engine_no_ambient_clock`,
`ranking_engine_no_randomness`) each exist for a specific reason:

- **No UI/platform imports** — so the same module can be ported to the server, and so
  it tests on the command line in milliseconds without a simulator.
- **No ambient clock** — timezone abuse is an explicit exploit in the Phase 2 test
  suite ("logging across boundaries to claim extra days"). You cannot write a
  deterministic test for a function that reads `Date()`. The date, calendar and
  timezone are parameters.
- **No randomness** — the Phase 4 cutover plan is to run *identical test vectors*
  against both the Swift and server implementations and verify they agree on real
  historical data. Non-determinism makes that verification impossible.

Each constraint is what makes a later step cheap. A single accidental `import SwiftUI`
quietly destroys the property, and you would not find out until the port.

## The sentence this buys you

> "I ran scoring client-side for latency and offline support, but I knew it had to
> become server-authoritative before any competitive feature shipped, so I designed
> the module to be portable from day one."

That is a materially more senior thing to say than describing any feature in the app.

## Reversal trigger

The client-side half is not reversible; it is the Phase 1–3 plan.

The server migration gate is **not negotiable and has no reversal trigger.** A
leaderboard everyone knows is cheatable is worse than having no leaderboard at all.
If Phase 4 arrives and the port is not done, the leaderboard does not ship.
