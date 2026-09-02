# Phase 1 — Single-Player Core

**Opened 2 September 2026 · Objective: an app you personally use every single day.**

§1: *"By the end of this phase the app does nothing clever. It logs food, logs weight,
reads HealthKit, and shows you a dashboard. No ranking, no tiers, no social. This is the
boring foundation that everything else stands on — and the phase where you become user
zero."*

The board lives in Jira (project NA, label `phase-1`). This file is the tracker; the
board is the working surface. [`jira-import.csv`](jira-import.csv) is what seeded it —
11 epics, 60 issues, 197 points, with acceptance criteria drawn from the brief, the
safety rules and the Phase 0 findings.

---

## The one thing that shapes the plan

**Twenty-one consecutive days is calendar, not work.** It is the only exit criterion no
amount of effort compresses, and Phase 2 cannot start without the data it produces —
your own three weeks of logs are the test set for the entire ranking engine.

So the board is not ordered by what is interesting or even by what is architecturally
tidy. It is ordered to reach the smallest daily-usable app as early as it honestly can,
start the clock, and ship everything else underneath a phase that is already counting
down. **Build all four logging paths before day 1 and you have not lost a week — you
have added one to the end of the phase.**

**Minimum set to start the clock:**

| | |
|---|---|
| Onboarding | produces a calorie band |
| Manual food entry | offline by construction |
| Weight entry | manual or from HealthKit |
| Local persistence | survives a rebuild |

Deliberately *not* on that list: barcode, photo estimates, background HealthKit
delivery, the outbox, Matchday polish. Every one of them can land on day 4 as easily as
on day 0.

**The standing rule once the clock runs:** a change that breaks a day's logging is a
fix-now bug by definition, because it resets a counter that costs three weeks to
rebuild.

> **Day 1 of 21:** `TO BE MEASURED` — record the date here the day it starts.

---

## Exit criteria

Phases end on a testable condition, not a date. The brief lists six; the seventh is
added here because `docs/safety/safety-requirements.md` makes S1–S7 Phase 1
requirements rather than Phase 3 polish, and the phase should not be able to close with
a gate quietly deferred.

- [ ] **21 consecutive days of real data logged** — non-negotiable, and the phase's actual purpose
- [ ] **All four logging routes work, offline included** — the brief says three paths; the redesign adds manual as a fourth, and it is the one that starts the clock
- [ ] **HealthKit incremental sync with a persisted anchor** — proven the way Spike A proved it: 56,764 samples on a first read, ~0 on the next
- [ ] **Weight trend rendering as a moving average** — 7-day EWMA; raw daily weight is never the primary series
- [ ] **Outbox sync verified in airplane mode** — a real day with the radio off, reconciled cleanly on reconnect
- [ ] **RLS policies on every table, tested with two accounts** — account A cannot touch account B's rows, proven repeatably
- [ ] **The seven §10 safety gates all built in** — S1 floor · S2 BMI rejection · S3 onboarding ceiling · S4 age gate · S5 lint rule active · S6 opt-out · S7 signposting

**On the dates.** §1 nominally runs 17 August – 13 September 2026. Phase 0 closed on 31
August, three weeks past its own window, effectively all of it spent waiting on Apple.
Those dates are stale and the repo convention settles it: the condition closes the
phase, not the calendar. The useful planning number is not an end date but the clock —
whatever day the minimum set lands, the phase cannot close fewer than 21 days later.

---

## The board

| Epic | What it covers | Pri |
|---|---|---|
| **P1-A** Foundations & app skeleton | Xcode project, `Packages/`, tokens wired in, macOS CI on, and the open type decision settled | Highest |
| **P1-B** Data layer, schema & RLS | Migration 001 with RLS from the first line, SwiftData, repositories, the food mirror | Highest |
| **P1-C** Authentication | Sign in with Apple, and Article 9 consent separate from ToS | High |
| **P1-D** Pre-Season: onboarding & the §10 gates | Mifflin-St Jeor as a band, S1–S7, the calibration window | Highest |
| **P1-E** HealthKit sync | Statistics-collection buckets, persisted anchor, background delivery, honest empty states | High |
| **P1-F** Sub On: food logging, four routes | Manual, search, barcode, photo, and the mandatory Under Review screen | High |
| **P1-G** The Run: weight & trend | Manual + HealthKit, 7-day EWMA, pace against the chosen rate | Medium |
| **P1-H** Matchday: the Today dashboard | Band, macros, sparkline, Form ring, division placeholder | High |
| **P1-I** Offline-first sync | Outbox, last-write-wins, airplane-mode verification | High |
| **P1-J** Dogfood: 21 consecutive days | The clock, plus the photo-accuracy benchmark it produces | Highest |
| **P1-X** Phase 1 exit criteria | The seven conditions above, mirrored as tickets | Highest |

The full ticket text — descriptions, acceptance criteria, the named safety tests — is in
[`jira-import.csv`](jira-import.csv). A rendered version of this plan, with the running
order laid out visually, is published at
<https://claude.ai/code/artifact/f88b3f68-612e-455d-86a0-c4d129e086df>.

---

## Running order

1. **Settle the type decision, then make a project exist.** ADR 0015 blocks every view
   ticket and nothing at all can start before `Ninety/` exists. Resist starting anything
   else beside these two.
2. **Schema and RLS before a single row exists.** RLS goes on in migration 001. By week
   three that database holds your own health data, and retrofitting it then is §1.1's
   *"genuinely bad afternoon"*.
3. **Onboarding, with the safety gates wired in as it is built.** S1–S4 are onboarding
   logic, not a review pass over finished screens. Each arrives with its test names
   already written in `docs/safety/`.
4. **Kick off.** The minimum set above. Record day 1.
5. **Everything else, underneath a running clock.** Barcode, photo, HealthKit, sync,
   Matchday polish.

---

## The first design task

**Fixed type scale vs Dynamic Type**, unresolved since the redesign and the one thing a
393×852 artboard could not settle. iOS wants system text styles and no hard-coded point
sizes; the mockups use the fixed scale because a static frame cannot express the
alternative. Whichever wins changes how the type tokens are structured, so it blocks
every view ticket.

Write it up as **ADR 0015** with a pre-written reversal trigger, and add the row to the
index in `docs/decisions/README.md`. Do not renumber.

---

## Two findings from Phase 0 that bind the build

Both measured on a real device, neither negotiable:

- **Never iterate raw HealthKit samples for a daily total.** ~1,830 step samples and
  ~3,000 active-energy samples *per day*. `HKStatisticsCollectionQuery` buckets inside
  HealthKit and returns 31 values instead of 56,764 objects.
- **There is no permission-denied branch to write.** A denied read returns an empty
  result identical to "no data", and iOS will never distinguish them. Every data surface
  needs one empty state whose wording covers both without claiming either.

Numbers and the full write-up: [`../phase-0/07-spike-findings.md`](../phase-0/07-spike-findings.md).

---

## Out of scope, and where it went

| | |
|---|---|
| Ranking maths, tiers, anti-gaming | Phase 2. `Packages/RankingEngine` is scaffolded now only so the lint purity rules have a boundary to police |
| The scoring half of S3 | Phase 2 — progress score peaking at target rate |
| Privacy policy, export, deletion, S7 triggers | Phase 3, before the first external tester |
| Friends and leaderboards | Phase 4 — but their two tables ship empty in migration 001, because retrofitting relationships hurts |
| PostHog | Phase 3 |
| Workout logging or UI | ADR 0009. Workouts are read passively and never surfaced |

---

## Handoff prompt for a fresh session

> I'm on Phase 1 (Single-Player Core) of Ninety. Building food logging, weight tracking,
> HealthKit sync, and the Matchday dashboard. Architecture: SwiftUI + `@Observable`
> ViewModels + protocol-based repositories, SwiftData local store with an outbox pattern
> syncing to Supabase.
>
> Currently working on: **[ticket]**.
>
> Requirements: offline-first (the UI never waits on network), RLS on every table, photo
> estimates always show ranges + confidence and require user confirmation. The safety
> rules in `docs/safety/` are Phase 1 requirements, not Phase 3 polish. Design tokens are
> generated — edit `ninety.tokens.json`, never the Swift.

The board is the source of truth for *what is next*; this file is the source of truth for
*what closes the phase*.
