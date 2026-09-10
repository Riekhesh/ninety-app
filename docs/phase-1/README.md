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

> **Day 1 of 21: 9 September 2026.** Day 21 is **29 September 2026** at the earliest —
> earliest, because a broken day restarts the count rather than extending it.
>
> **What day 1 actually was, because it is not what the plan assumed.** Food went in
> through P1-F's routes, which closed on a device that morning. The weight was the one
> Pre-Season had already recorded — the weight-*entry* surface did not ship until day 2
> (P1-G, 10 September). So day 1 met *"real food, real weight"* on a weight the app
> collected at onboarding rather than one the user chose to record that day. That is a
> real reading of a real body and it counts; it is written down here rather than
> smoothed over, because the repo convention is that a criterion closed on different
> evidence than planned says so.

**Decided 8 September: the clock runs in two halves, and the first half is not in
Ninety.** Logging starts in MyFitnessPal *today*, because the app cannot log a meal
until P1-F's manual route exists and there is no reason for the calendar to wait on the
build. When manual entry and weight entry ship, logging moves into Ninety and stays
there; the MyFitnessPal stretch is imported behind it.

**The imported days are marked as imported and are not pretended to be Ninety days.**
`EntryMethod` gains an `imported` case — a Postgres enum value and a line in
`Domain.swift`, with `check_schema_parity.py` keeping the two sides honest — so Phase 2
can tell the two halves apart. They are genuinely different data: the imported days
carry food-database calories and no friction signal, and the Ninety days carry
hand-entered estimates and a real reading on whether this app gets used. Consistency is
weighted 0.50, and it measures showing up *given the friction*, which a polished
third-party app with a barcode scanner does not test.

What this buys is a week or more of wall clock, on the one criterion no effort
compresses. What it costs is that the first stretch says nothing about the app itself —
which is the half of P1-J's purpose the second stretch covers.

> **Overtaken by events, 10 September — and this is the honest version rather than a
> deletion.** The two-halves plan was written on the 8th expecting *"a week or more"* of
> MyFitnessPal logging before Ninety could take over. P1-F closed on the 9th and P1-G on
> the 10th, so the answer turned out to be **one day**, and the clock's day 1 is a Ninety
> day rather than an imported one.
>
> **`EntryMethod.imported` was therefore never built.** No Postgres enum value, no case in
> `Domain.swift` — `check_schema_parity.py` reports four values on both sides and is
> right to. The reasoning behind it still stands and is worth keeping: imported days carry
> food-database calories and no friction signal, and consistency at 0.50 measures showing
> up *given the friction*, which a third-party app with a barcode scanner does not test.
> If the 8 September MyFitnessPal day is ever wanted in the dataset it needs the enum
> value, a migration and the parity check — **a decision, not a chore**, and one worth
> weighing against the alternative of simply letting the clock be twenty-one Ninety days.
> Nothing is blocked either way.

**Two things the minimum set gets wrong as written**, found closing P1-D:

- ~~**Weight entry is a blocker and is not built.**~~ **Fixed 10 September by P1-G.** It
  was right about the problem and one day out on the consequence: onboarding wrote one
  `WeightLog` and The Run was a holding screen, so there was no way to record tomorrow's
  weight — but yesterday's had already been recorded, which is what let day 1 be the 9th
  rather than the 10th. The reordering it caused was still the right call: weight entry
  went to the front of step 6 and shipped in one session.
- **Backdating a log is normal use, not backfill.** `FoodLogDraft` already takes
  `loggedAt`, and the 48-hour lock is on *editing* an existing log rather than on creating
  one with an earlier timestamp. Logging last night's dinner this morning has to work, or
  the streak breaks for a reason that has nothing to do with whether the food was eaten.
  What "no synthetic backfill" is protecting against is reconstructing days from memory —
  guesses that Phase 2 would then tune an engine on.

---

## Exit criteria

Phases end on a testable condition, not a date. The brief lists six; the seventh is
added here because `docs/safety/safety-requirements.md` makes S1–S7 Phase 1
requirements rather than Phase 3 polish, and the phase should not be able to close with
a gate quietly deferred.

- [ ] **21 consecutive days of real data logged** — non-negotiable, and the phase's actual purpose. **Running since 9 September**; earliest close 29 September. The standing rule below applies from here on: anything that breaks a day's logging is a fix-now bug, because it resets a counter that costs three weeks to rebuild
- [x] **All four logging routes work, offline included** — the four routes closed with P1-F on 9 Sep; the *offline included* half closed with P1-I's airplane-mode day on 10 Sep, on a real phone with the radio off. **Closed on different evidence than the wording implies, and the difference is worth stating rather than glossing:** three routes work with no signal — manual by construction, search degraded to the phone's own foods, barcode against the local cache — and **the photo route does not and never will**. §1.3 puts the model behind an Edge Function precisely so no key ships in the binary, so "photo works offline" was never achievable and was never what this asked for. What it asked for is that no route *loses* anything offline, and that holds: the photo screen says it cannot reach the estimator and names the three routes that need no signal, and nothing on any of them waits on a network
- [ ] **HealthKit incremental sync with a persisted anchor** — proven the way Spike A proved it: 56,764 samples on a first read, ~0 on the next
- [x] **Weight trend rendering as a moving average** — 7-day EWMA; raw daily weight is never the primary series. **Closed 10 Sep by P1-G**, on the evidence the criterion was written for: the chart renders on a real phone, the headline figure is the smoothed value and the raw dailies are off behind a toggle that resets every time the screen appears. `WeightTrend` is pure and carries 16 tests and 48 assertions, including the gaps that ADR 0020 is about
- [x] **Outbox sync verified in airplane mode** — a real day with the radio off, reconciled cleanly on reconnect. **Closed 10 Sep by P1-I**, on exactly the evidence the criterion was written for: the app was used on a real phone with the radio off and the queue reconciled on reconnect. Not a synthetic test — the criterion's own wording is *"gyms and restaurant basements have no signal, this is the scenario"*. Underneath it, 270 tests in 21 suites cover the parts a day cannot: the queue kept whole with no connection and **nothing charged an attempt for it**, the coalescing of a meal logged and corrected offline into one upsert, the dependency order that puts a custom food ahead of the log referencing it, and a drain that never touches what was logged. `Settings → Sync` is the instrument the day was read off, and it exists for that reason
- [ ] **RLS policies on every table, tested with two accounts** — account A cannot touch account B's rows, proven repeatably
- [x] **The seven §10 safety gates all built in** — S1 floor · S2 BMI rejection · S3 onboarding ceiling · S4 age gate · S5 lint rule active · S6 opt-out · S7 signposting. **Closed 8 Sep by P1-D**, on the evidence it was written for: every gate has the named tests `docs/safety/safety-requirements.md` asks for, all of them ran green on a device, and the flow was walked including an under-18 date of birth. Two halves are later phases *by the criterion's own wording* and are not silently included — S3's scoring half is Phase 2, S7's pattern triggers are Phase 3

**On the dates.** §1 nominally runs 17 August – 13 September 2026. Phase 0 closed on 31
August, three weeks past its own window, effectively all of it spent waiting on Apple.
Those dates are stale and the repo convention settles it: the condition closes the
phase, not the calendar. The useful planning number is not an end date but the clock —
whatever day the minimum set lands, the phase cannot close fewer than 21 days later.

---

## The board

| Epic | What it covers | Pri |
|---|---|---|
| **P1-A** Foundations & app skeleton | **CLOSED 8 Sep.** Built 2 Sep, compiled and run on a real device 8 Sep. Xcode project, `Packages/`, tokens wired in, macOS CI gated, type decision settled | Highest |
| **P1-B** Data layer, schema & RLS | **4 of 5 done; compiled and green 8 Sep.** Migrations applied to the live project, RLS proven with two accounts, SwiftData models, repositories. One bug the first run found (see below). Food mirror deferred | Highest |
| **P1-C** Authentication | **CLOSED 8 Sep.** Sign in with Apple through Supabase's id-token exchange, Article 9 consent recorded separately from ToS. Verified on a real device against the live project | High |
| **P1-D** Pre-Season: onboarding & the §10 gates | **CLOSED 8 Sep.** All ten stories, compiled, 104 tests green, walked on a real device. Onboarding, the band, S1–S7, the Settings screen, and the calibration window — now seven days (ADR 0018) | Highest |
| **P1-E** HealthKit sync | Statistics-collection buckets, persisted anchor, background delivery, honest empty states | High |
| **P1-F** Sub On: food logging, four routes | **CLOSED 9 Sep.** All four routes walked on a real device against the live project, 175 tests green. Manual, search, barcode, photo, the Squad and the Bench, the Under Review gate, the Edge Function and its per-user cap, the Today list, and the food mirror | High |
| **P1-G** The Run: weight & trend | **CLOSED 10 Sep.** All four stories, walked on a real device: weight entry (manual + Apple Health), the 7-day EWMA in Swift Charts, the zero/one/handful/week states, and the pace against the S3-filtered rate. 231 tests, 19 suites. ADR 0020 settles what the average is an average of | Medium |
| **P1-H** Matchday: the Today dashboard | **Written 10 Sep, NOT YET COMPILED.** All four stories and the task: the band and the pitch, the Form ring, the macro split with its coverage line, the weight sparkline off the same `WeightTrend`, the division placeholder, and the team sheet grouped by meal. [ADR 0022](../decisions/0022-meals-are-slots-derived-and-overridable.md) settles the parked slot question. Needs a Mac session — see below | High |
| **P1-I** Offline-first sync | **CLOSED 10 Sep.** Both stories, walked on a real phone including a day with the radio off. `Ninety/Sync/` drains the outbox: one plan per row, dependency order, last-write-wins on server timestamps, backoff, parked rows, and the panel in Settings the day is read off. ADR 0021 settles the drain policy. 270 tests, 21 suites | High |
| **P1-J** Dogfood: 21 consecutive days | The clock. **The photo-accuracy benchmark is deferred** — see below | Highest |
| **P1-X** Phase 1 exit criteria | The seven conditions above, mirrored as tickets | Highest |

The full ticket text — descriptions, acceptance criteria, the named safety tests — is in
[`jira-import.csv`](jira-import.csv). A rendered version of this plan, with the running
order laid out visually, is published at
<https://claude.ai/code/artifact/f88b3f68-612e-455d-86a0-c4d129e086df>.

---

## Running order

1. ~~**Settle the type decision, then make a project exist.**~~ **P1-A, 2 Sep.**
   ADR 0015 is written and `Ninety/` exists. It has not been compiled — the work was
   done in a Linux container with no Xcode — so P1-A closes on the
   [first Mac session](#first-mac-session), not on the commit. See
   [what P1-A landed](#p1-a--what-landed).
2. ~~**Schema and RLS before a single row exists.**~~ **P1-B, 2 Sep.** RLS goes on in
   migration 001. By week three that database holds your own health data, and retrofitting
   it then is §1.1's *"genuinely bad afternoon"*.
3. ~~**A signed-in user, because every row is keyed on one.**~~ **P1-C, 7 Sep.** Every
   table references `auth.users.id` and every policy compares `auth.uid()`, so there is
   nowhere to put a food log until this exists. It brings the Article 9 consent screen
   with it — the screen belongs to onboarding, but the consent is what makes the logging
   lawful, so it cannot land after the thing it authorises. See
   [what P1-C landed](#p1-c--what-landed).
4. ~~**Onboarding, with the safety gates wired in as it is built.**~~ **P1-D, 8 Sep —
   closed.** S1–S4 are onboarding logic, not a review pass over
   finished screens, and each arrived with its test names already written in
   `docs/safety/`. It carried the first Settings surface, which is where S6's opt-out,
   S7's signposting and P1-C's consent withdrawal all live. See
   [what P1-D landed](#p1-d--what-landed).
5. ~~**Kick off.** Manual food entry and a weight-entry surface. Record day 1.~~
   **Done. P1-F closed 9 September, P1-G on 10 September, and the clock started on
   9 September** — the day food could first be logged in Ninety, on the weight
   Pre-Season had already recorded. See [the clock](#the-one-thing-that-shapes-the-plan)
   for what day 1 actually consisted of.
6. **Everything else, underneath a running clock**, in this order: ~~P1-G ·~~ ~~P1-I ·~~
   ~~P1-H~~ · **P1-E**, then P1-J and P1-X. P1-H is written and unbuilt as of
   10 September, so it is struck through here on the same terms P1-A was: the commit is
   not the close, the Mac session is. **The clock is running as of 9 September, so this
   is no longer a plan — it is the order the remaining epics land in while the days
   count.** P1-I closed on 10 September, airplane-mode day included, so the three weeks
   are no longer sitting on one phone with nothing draining the outbox. Sync was second
   rather than last for two reasons, and both proved right: three weeks of the only
   irreplaceable asset in the project were living on one phone with nothing draining the
   outbox, and the airplane-mode criterion needs real logging days to reconcile — so it
   had to happen *during* the clock rather than at the end of it. HealthKit is late
   because it is retroactive: a first read pulls the history back whether it lands on day
   4 or day 18.

> **Changed 8 September: P1-F was built whole rather than split.** The plan above put
> manual entry at step 5 and *"P1-F's remaining routes"* after four other epics, on the
> reasoning that barcode and photo can land on day 4 as easily as day 0. That reasoning
> is still right about the *clock* and turned out to be wrong about the *work*: the four
> routes are not four features, they are one screen and one write path with four ways in,
> and the pieces that would have been deferred — the Under Review gate, the Edge
> Function, the cap, the estimate row — are the ones that would have had to be designed
> around when the rest landed. Building them together cost one session; splitting them
> would have cost the same session twice and left the schema of `photo_estimates`
> speculative in the meantime. **Nothing about the clock changed**: manual entry still
> starts it, and it starts it the moment this compiles on a Mac.
>
> What this does move is P1-B's food mirror, which is now a prerequisite of two of the
> four routes rather than a deferred story: search and barcode both resolve against it.

> **Changed 9 September: P1-G moved to the front of step 6.** The order was P1-I · P1-H
> · P1-E · P1-G, on the reasoning that sync protects three weeks of irreplaceable data
> and HealthKit is retroactive. Both still hold — but with P1-F closed, **weight entry is
> the only thing left between here and day 1**, and this file has said so since 8
> September without the order reflecting it: *"P1-J's own criterion is 'real food, real
> weight', so a weight-entry surface is part of day 0, not part of P1-G's chart work."*
>
> Food can be logged today and is not being counted, because half the pair does not
> exist. Everything in the old order is a thing that improves a clock that is already
> running; P1-G is the thing that starts it. Nothing else has that property, and the
> twenty-one days are the one cost no effort compresses.
>
> **Only the weight-entry half is day 0.** The 7-day EWMA, the chart and the pace against
> the chosen rate are P1-G's own work and can land underneath the clock like everything
> else.

---

## The first design task — closed 2 September 2026

**Fixed type scale vs Dynamic Type.** Settled in
[ADR 0015](../decisions/0015-dynamic-type-with-a-bundled-face.md): Dynamic Type at every
style, no exceptions, carried by two bundled faces rather than by San Francisco.

The third thing the framing hid: neither option was what the generated Swift actually
did. It emitted `Font.system(...)`, so shipping it would have resolved the question in
favour of *neither* — rendering a world built on Saira Condensed lettering entirely in
the platform sans. The tokens now carry the faces, and `generate.py` fails the build on a
style the bundled families cannot render.

**Consequence for the artboards:** their sizes are the Large baseline, not the layout.
Every screen holding a metric owes a reflow at accessibility sizes.

**Still outstanding:** Matchday captured at `.xSmall` and `.accessibility5`. **There is
now a dashboard to photograph** — P1-H ships both previews by name, and every panel on it
grows with the type through `@ScaledMetric` rather than sitting at a fixed size. What is
still outstanding is the *capture*, which needs the device session that builds it. The
mechanism and the harness have existed since P1-A (every view ships an `.accessibility5`
preview; `DesignSystemTests.typeScales` asserts all sixteen styles respond to the content
size category).

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

## P1-A — what landed

Seven tickets, 16 points, on branch `p1-a`. **Written, not yet built:** every line of
this was produced in a Linux container with no Xcode, Swift toolchain or simulator, so
the epic is not closed until a Mac has compiled it. Everything that *could* be checked
without a toolchain has been, and is marked as such below.

| Ticket | Outcome |
|---|---|
| DECIDE: type scale (ADR 0015) | Dynamic Type everywhere, plus two bundled faces. ✔ font tables parsed and verified; accessibility-size capture carried to P1-H |
| Create the `Ninety/` Xcode project | iOS 18.0, Swift 6 strict concurrency, synchronized folders, SwiftLint build phase. ✔ pbxproj reference-checked; ✗ never opened |
| Wire `DesignTokens.generated.swift` in | In the app target's Sources phase; `generate.py` now also emits the two asset-catalogue colorsets. ✔ `--check` green |
| Scaffold `Packages/RankingEngine` | Pure SPM package, zero dependencies, Swift Testing target. ✗ `swift test` not run |
| Switch on the gated macOS CI job | Ubuntu `triage` job decides before a macOS runner starts. ✔ filter tested against 14 real paths |
| Enable the hooks, prove the lint fires | `scripts/verify-guardrails.sh`. ✔ all four hook checks fire; ✗ lint half needs swiftlint |
| App shell: three tabs, no more | Matchday · The Run · The Table, Sub On as a sheet. ✗ never rendered |

**Three things found while building it, each of which would have cost more later:**

- **`.gitignore` had a bare `Packages/`.** Standard in Swift gitignores, where it means
  the old Xcode checkout directory. Here it would have silently excluded the entire
  ranking engine from git — no error, nothing to notice.
- **The generated Swift named no font.** The whole Matchday lettering decision was
  about to be resolved by omission. See ADR 0015.
- **The macOS job's guard was inside the job.** Its per-step probe could skip the
  *steps*, but the runner was already billed. The gate is now a separate Ubuntu job.

**Compiled and run, 8 September — P1-A is closed.** It was written in a Linux
container with no Xcode, no Swift toolchain and no simulator, and that caveat stood for
six days. The first Mac session built it, ran the full suite, and installed it on a real
phone: `Bundled faces registered: 7`, the shell renders, and Dynamic Type reflows. The
runbook that closed it is still [below](#first-mac-session), because a fresh clone needs
it even though this epic no longer does.

---

## P1-B — what landed, and the one thing deferred

Four of five stories, 20 of 28 points. Migrations 001–003 are applied to the
live project (`sxaewrpojdadywuybzhz`, London, Postgres 17).

| Story | Outcome |
|---|---|
| Migration 001: every table, RLS from the first line | ✔ Ten tables, RLS enabled in the same migration that creates them |
| RLS policies, tested with two real accounts | ✔ 27 assertions, `scripts/verify-rls.sh`, in CI on every schema change |
| SwiftData models as the local source of truth | ✔ Eight `@Model` types, versioned schema, migration plan |
| Protocol-based repositories with mocks | ✔ Four protocols, SwiftData and mock implementations |
| Mirror Open Food Facts + USDA | **Done 9 Sep** — 142,068 UK-tagged foods in the live project, plus the ranked `search_foods` function. A scanned tin resolves against it |

**The mirror is deferred to sit alongside P1-F.** It is 8 of the epic's 28
points and nothing in the minimum daily-usable set needs it: manual entry is
what starts the clock, and text search is P1-F's Path 1, which is where the
data is first actually read. The `foods` table already carries its
`search_vector` column and GIN index, so the import is a data job rather than a
schema change when it lands. Twenty-one days is the one thing in this phase no
effort compresses, so anything that can start the clock sooner does.

**Two bugs the RLS proof caught before they shipped.** The forged-insert
assertions were passing because a UNIQUE constraint rejected the row, not a
policy — with the insert policy deliberately replaced by `with check (true)`
the test still passed. And a comment in 002 claimed an UPDATE policy with only
`using` lets a row be reassigned to another user; it does not, and the
correction is now an assertion rather than a sentence. Both are in the commit
history with the experiments that established them.

**One bug the first ⌘U found, and it was P1-B's.** `OutboxEntry` stored a
property called `entity`. `@Model` is backed by `NSManagedObject`, which already
owns a property of that name holding an `NSEntityDescription`, so the attribute
shadowed it — compiling perfectly and then trapping inside
`ModelContext.save()` with *"Could not cast value of type 'NSEntityDescription'
to 'NSString'"*, a message naming neither the property nor the model. Every
write in the app goes through the outbox, so it broke all four repositories at
once; it surfaced in a different test on each run only because tests run
concurrently and whichever reached an outbox save first crashed the process.
Renamed to `tableName`, and `scripts/check_schema_parity.py` now refuses any
model property that shadows an `NSManagedObject` one. The Postgres column is
still `entity` — mapping a column name is P1-I's job and is cheaper than this
was to find.

**Compiled and green, 8 September**, and the first execution immediately earned its
keep — see the `OutboxEntry.entity` bug above, which broke every write in the app and
which nothing but running it could have found. The caveat below is kept as the record of
what the state was.

**Was: still not compiled.** The Swift in this epic was written
in a Linux container with no Xcode. The SQL *is* verified — against a real
Postgres 16 locally and applied to the live project — but the models,
repositories and their tests have never been built. First Mac session: ⌘U.

---

## P1-C — what landed

Both stories, 8 points, on branch `p1-c-lmapdw`. Two ADRs, because two questions
turned out to be real decisions rather than implementation details.

| Story | Outcome |
|---|---|
| Sign in with Apple via Supabase Auth | ✔ Id-token exchange, no scopes requested, Keychain-backed session restored on cold launch, refresh left to the SDK. Failure states in the copy deck's words |
| Health consent, separate from terms acceptance | ✔ Two columns, two calls, two timestamps, no API that writes both. `ConsentTests.healthConsentIsSeparateFromTermsAcceptance` is the named test |

**Three decisions worth reading, all in the ADRs:**

- **[ADR 0016](../decisions/0016-sign-in-with-apple-only.md) — Apple only, and no
  anonymous sessions.** Anonymous sessions would have started the 21-day clock
  sooner and charged it back later: upgrading one to a real identity is a data
  migration on a live device holding health data, and the days most at risk are
  the first ones, which are the calibration window. The measured cost of not
  doing it is one screen with one button, shown once.
- **[ADR 0017](../decisions/0017-health-consent-separate-from-terms.md) — a
  partial consent does not start the app.** The S6 opt-out *must* leave a fully
  useful tracker, because an opt-out that cripples the app is a threat. Health
  consent is the opposite case: there is no version of Ninety that is not
  processing health data, so a "limited mode" would be a tracker quietly logging
  food without the consent that makes logging it lawful. The screen offers the
  honest alternative instead — sign out.
- **No name, no email, no Apple user identifier.** `requestedScopes = []`. Apple
  offers all three exactly once and Ninety takes none of them; a field never
  collected cannot go stale behind Hide My Email, cannot leak, and does not have
  to appear on an Article 9 export or in the App Privacy labels.

**Two things found while building it, each cheap now and expensive later:**

- **xcconfig eats everything after `//`.** Putting `SUPABASE_URL = https://x.supabase.co`
  in a build setting silently yields `https:` — no warning, and the failure
  surfaces as a sign-in that does not work. The setting is `SUPABASE_HOST`, the
  host alone, and Swift puts the scheme back. It also means the setting cannot
  point the app at a plaintext endpoint.
- **The two Supabase values had nowhere safe to live.** Neither is a secret
  (`docs/security/secrets.md` puts both in the "ships in the bundle" row, because
  RLS is the boundary) but both name one person's project, and this repository is
  read by other people. They now follow `DEVELOPMENT_TEAM` exactly: declared empty
  in `Config/Ninety.xcconfig`, filled in from the gitignored `Local.xcconfig`, and
  `scripts/check_bundle.py` fails CI if a literal ever reaches `Info.plist`.

**The gap, named rather than buried — and it is two gaps, not one.** Consent can
be withdrawn on the consent screen, and `ConsentRecorder` supports withdrawing
either at any time; **and the only "Sign out instead" button is on that same
screen.** Once both consents are given the shell moves on and neither is
reachable again, because Ninety has no Settings screen at all yet. The consent
copy therefore describes what withdrawal *does* rather than promising where to
find it. Signing out currently means deleting the app — which does work, since
iOS clears an app's Keychain items on uninstall, but it is not a feature.
**P1-D closes both**: the screen carrying S6's opt-out switch and S7's
signposting carries these too.

> **Closed 8 September.** Settings exists — a sheet from Matchday's masthead — and it
> carries both consent switches and sign out alongside the opt-out and the signposting.
> The paragraph above is kept as the record of what the state was when P1-C shipped;
> read it in the past tense.

**One thing the device run changed, and it came from a warning rather than a
failure.** `supabase-swift` logs that `authStateChanges` emits its initial
session only *after* attempting a refresh, so a launch with no signal and an
expired access token emits nil — and an observer taking that at face value signs
the user out for being on the Underground. ADR 0005 is explicit that the UI never
waits on the network, and §1.3 is explicit about where people actually log food.
`restore()` now keeps a stored session when the only thing that failed was
reaching the server, and the change-stream falls back to the Keychain rather than
to nil. Both are in `SupabaseAuthService` and neither is covered by a test: the
mock cannot model the SDK's own storage, which is the honest limit of putting the
lock-in behind one file.

**Verified on a real device, 8 September.** The epic's own acceptance criteria
are met rather than argued for: Sign in with Apple completes against the live
project, the session survives a cold launch (`Session restored; refresh handled
by the SDK.`), consent is recorded as two separately-timestamped decisions, and
all 43 tests pass on device — including
`test_health_consent_is_separate_from_terms_acceptance`.

**Four things the first execution found, none of which a compiler could have.**
Three were real defects and the fourth was a warning worth acting on:
`OutboxEntry.entity` shadowing `NSManagedObject.entity` (P1-B's, and it broke
every write in the app); `SupabaseConfiguration` accepting the truncated
`https:` its own guard existed to reject; a session signed out on an offline
launch; and `Library/Application Support` not existing on a fresh install, which
buried the first launch in CoreData recovery errors. Each has a check or a
comment behind it now, and two of them added a tripwire that runs on Ubuntu.

**Still outstanding.** Same caveat as P1-A and P1-B,
plus one more that is new. This was written in a Linux container with no Xcode,
so nothing is compiled — and P1-C is the first epic to take a **remote** Swift
package (`supabase-swift`, pinned to 2.x). It has never been resolved, so
`Package.resolved` does not exist and the SDK call sites have never seen a
compiler. If any of them have moved, they are all in
`Ninety/Auth/SupabaseAuthService.swift` and nowhere else — which is the whole
reason `AuthServiceProtocol` exists. The package resolved to **2.55.1** and the
adapter compiled against it unchanged.

The honest remainder is that adapter's own behaviour. The mock cannot model the
SDK's session storage, so the offline-launch path and the change-stream fallback
are reasoned about and observed on a device, not asserted by a test.

---

## P1-D — what landed

Ten stories, 33 points, on branch `p1-d-settings-screen-61nym8`. One ADR, because one
number the brief fixed turned out to be a decision rather than a constant.

| Story | Outcome |
|---|---|
| Pre-Season onboarding flow | ✔ Four steps — about you · starting weight · goal · your band. Resumable from the values on the row rather than from a remembered position |
| Mifflin-St Jeor, presented as a band | ✔ `EnergyTarget`, rendered as a figure plus a tolerance everywhere. Recomputes from the profile, never stored |
| S1 · calorie floor, clamping | ✔ Clamped after the deficit, with the slower-rate offer. Five named tests |
| S2 · goal weight against BMI 18.5, rejecting | ✔ Refused, never substituted, and the refusal names the lowest acceptable weight. Five named tests |
| S3 · rate ceiling in onboarding | ✔ `min(1.0, 1% of body weight)`, filtered rather than disabled, and clamped again on the way to the store. Three named tests |
| S4 · age gate, hard stop | ✔ Computed on the actual date, written down so it survives a relaunch, and it signposts. Five named tests |
| S5 · no punishment framing | ✔ The verbal half was already lint + `SafetyCopyTests`; this added the structural half as types — `Tone`, `BandState`, `DayMark` |
| S6 · competitive opt-out | ✔ `CompetitiveFeatures`, two taps from Matchday, reversible, and the right-hand column asserted under both states of the switch |
| S7 · signposting in Settings | ✔ Permanent section, no diagnostic language, and the age-gate screen carries the youth helpline |
| Calibration window | ✔ Seven days (ADR 0018), stamped once, correct across a date change and a timezone change |

**The two gaps P1-C named are closed.** Consent can be withdrawn from
`Settings → Your consent` — the same two switches, in the same shape, because withdrawal
that is harder than giving means the consent was not freely given — and signing out is a
button rather than deleting the app. Withdrawing health consent puts the consent gate back
up, dismissing Settings on the way, because the app has just lost the lawful basis for the
screen underneath it.

**One decision, and it is a change to the brief rather than an implementation detail.**
[ADR 0018](../decisions/0018-seven-day-calibration-window.md) — **the calibration window is
seven days, not fourteen.** §2.3 fixed it at a fortnight; the cost of that was never
written down, and it is that a new user does not see the thing the product is *for* until
their third week, in the exact fortnight §1.5 says weight-tracking apps get abandoned. The
ADR states what the shorter window costs rather than pretending it is free: outlier
rejection over seven points leaves five, one unusual week is now the whole baseline, and
Phase 2 inherits two constraints — a baseline statistic that is robust at n=7, and a first
tier that can move in week two without reading as a punishment.

**Four things found while building it, each of which would have been worse later:**

- **The copy deck contradicted `PRODUCT.md` about the band.** The deck's band screen said
  `1,750–1,950 kcal`; `PRODUCT.md` says a single figure plus a tolerance, *never* two
  numbers joined by a dash. The deck is corrected and the renderer only knows how to
  produce the tolerance form.
- **The age gate's button did nothing.** The deck said `Close`. An iOS app cannot close
  itself, so on the one screen where the user has no other move, the only control was a
  no-op. It signs out instead — which is not a bypass, because the date of birth is on the
  profile and signing back in lands in the same place.
- **The band screen had to be where the flow's write happens.** `hasCompletedPreSeason` is
  derived from the values on the row rather than from a flag, which is what stops the app
  getting past its own gate with a nil date of birth. But it means writing the goal a
  screen early would let anyone who quit on the last screen into the app having never seen
  the calibration explainer — the one screen that says why there is no division yet, and
  where §2.3's anti-sandbagging is stated out loud rather than hidden.
- **The S7 sweep failed on a charity's name.** A test that forbids diagnostic language in
  the signposting copy fails on *"National Alliance for Eating Disorders"* and on Beat's
  own domain. The split is between what Ninety says and what the organisations are called;
  the check runs over the first.

**One thing deliberately not built.** Export and deletion are Phase 3, and Settings does
not mention them. A data-rights action listed in Settings that does nothing is worse than
one that is not listed.

**Compiled, green and walked on a device — 8 September.** The epic was written in a Linux
container with no Xcode, no Swift toolchain and no SwiftLint (the sandbox's proxy also
blocks fetching a Linux build), and that caveat stood for the length of the branch. It is
closed on **104 tests passing** and on the flow being walked end to end on a real phone: an
under-18 date of birth reaching the hard stop and surviving a sign-out and back in, S2
refusing a goal weight below BMI 18.5, S3's rate list shortening when the weight is edited,
the opt-out taking The Table away and giving it back, and health consent being withdrawn
from Settings and putting the gate back up.

**Six things the first execution found, and what each cost.** None of the six was a
compile error in the interesting sense — the app built once the four below were fixed, and
the rest is the class of defect only running the thing surfaces.

| Found by | What it was |
|---|---|
| `generate.py --check` | `claude-design-brief.md` was committed stale. It is generated from `brief.template.md`, which moved for ADR 0018 *after* the last check ran |
| SwiftLint `--strict`, first run ever on this branch | Three violations, two of them caused by the new `Screen` accessory slot: a call passing one labelled and one trailing closure, `@ViewBuilder` on its own line above a *variable*, and a `///` block documenting a file rather than a declaration |
| ⌘B | `frame(maxWidth:height:)` is not an overload — SwiftUI has a fixed `frame(width:height:)` and a flexible one and no mixture, so a flexible width with a fixed height means pinning both height bounds |
| ⌘U | `leapDayBirthdayIsHandledByTheCalendar` asserted the wrong thing. See below |
| Running it | **The sign-in button was drawing as a white slab down most of the screen** — P1-C's, not this epic's. See below |
| Running it | Nothing else. The console is clean apart from Apple's own `TUIKeyplane` keyboard constraint break and the known `supabase-swift` initial-session warning, which `SupabaseAuthService.observe()` already documents |

**The leap-day test was wrong and the gate was right.** It asserted that someone born on 29
February 2008 is blocked on 28 February 2026 and turns 18 on 1 March. `Calendar` treats 28
February as the anniversary in a non-leap year and says 18 a day earlier. The assertion was
an unchecked assumption about Foundation written as a requirement — which is the exact
failure the suite's own header warns about — and it is worth noticing that a *safety* test
was the one that got it wrong. The gap it exposes is real and is now recorded in
`docs/safety/safety-requirements.md` as a question for the Phase 3 review: the gate opens a
day early for one birthday in four years, and closing that needs the hand-rolled leap
arithmetic S4 avoids everywhere else.

**The sign-in button had no height, and it is the same bug P1-C fixed on the other axis.**
`SignInWithAppleButton` is a `UIViewRepresentable` with no intrinsic height in SwiftUI's
layout; the frame said `minHeight:` with no maximum, so it took every point the VStack
offered (509 on an iPhone 17) and UIKit "recovered" by breaking Apple's own `height <= 64`.
P1-C recorded the width version of this and its unsatisfiable-constraint log; the height
version was in the same expression and shipped. **It also means "verified on a real device,
7 September" was verified with a white slab on the first screen** — worth remembering about
what that phrase covers. Fixed here because it blocks walking the flow at all.

---

## P1-F — what landed

All seven stories plus the deferred P1-B mirror, on branch
`claude/p1-f-food-logging-4g8w6s`. **Written, not yet built:** every line of Swift in
this epic was produced in a Linux container with no Xcode, Swift toolchain or
simulator, so the epic is not closed until a Mac has compiled it and a phone has
logged a real meal through each route. That is the same caveat P1-A and P1-B carried
for six days, and it is the honest state rather than a formality — the first ⌘U on
P1-B found a bug that broke every write in the app.

Everything that *could* be checked without a toolchain has been, and is marked as
such below.

| Story | Outcome |
|---|---|
| Sub On: four routes, the Squad and the Bench | Team sheet first, routes above it. `TeamSheet` is pure and tested; First Half / Second Half derived from `logged_at` in the user's calendar. ✔ 16 tests; ✗ never rendered |
| Path 0: manual entry | Name, portion, calories, optional macros, and "keep this for next time". Offline by construction — nothing on the path is `async`. ✔ tested; ✗ never rendered |
| Path 1: text search | Local-first, catalogue second, 250 ms debounce. `search_foods` ranks by `ts_rank`. ✔ tested, including the SQL against a real Postgres |
| Path 2: barcode | `DataScannerViewController`, ~70 lines including the comments. Local cache before the network; a miss offers search or a custom food carrying the barcode. ✔ resolution logic tested; ✗ the scanner itself needs a device |
| Path 3: photo estimate | Downscale → Storage → Edge Function → validate. Provider interface ported from the spike, Gemini default. ✔ validation and downscale tested; ✗ no round trip has happened |
| Under Review | Mandatory. `confirm` is the only method on the route that can write. ✔ 14 tests; ✗ never rendered |
| Per-user daily photo cap | Server-side, atomic, thirty a day. ✔ **proven against real Postgres** — it counts to the limit and refuses past it, in `verify-rls.sh` |
| Keep the photo alongside the confirmed values | One `photo_estimates` row per item, written in the same transaction as its log. ✔ tested, plus the CSV export |
| *(P1-B)* Mirror Open Food Facts + USDA | `scripts/import_food_mirror.py`. ✗ not run — needs the ~10 GB export and the live project |

**Thirty-three RLS assertions now, up from twenty-seven**, and eleven tables. The new
ones cover the photo-cap ledger from both directions — B cannot read A's quota, and B
cannot write its own — plus two smoke tests on `search_foods` that only a real
Postgres can answer.

### Four things found while building it

- **Counting `photo_estimates` would have been the wrong cap.** The obvious
  implementation of §10's daily limit is `count(*)` over the confirmations, and it
  misses exactly the requests the cap exists for: a row is only written when the user
  gives the decision, so an abandoned estimate — or one a looping client never shows
  anybody — costs a model call and leaves no trace. The ledger counts *requests*,
  claims them atomically in one statement, and is not refunded on a failed model call.
  See [migration 005](../../supabase/migrations/20260908000005_photo_estimate_usage.sql).

- **The confirmed values are not weighed, and the spike says that makes them
  worthless as a baseline.** ADR 0010 folded the photo benchmark into Phase 1 on the
  condition that logging keeps the photo next to the confirmed values. It does — but
  `spikes/vision-accuracy/README.md` requires ground truth weighed on a scale, and a
  user nudging a portion on Under Review is not weighing anything. The set is real and
  worth having; it measures **correction magnitude**, not accuracy, and every exported
  row says so in its `notes` column. [ADR 0019](../decisions/0019-photo-logs-are-a-correction-dataset.md)
  records it, and the honest consequence is that the 20 weighed meals are *more*
  needed rather than less.

- **A nested `enum State` inside a SwiftUI `View` shadows `@State`.** Caught by
  reading rather than by a compiler, because there is no compiler here. Renamed to
  `Lookup`, with the reason in the code — it is the sort of thing that produces a
  confusing error a long way from its cause.

- **"The only file in the app that imports the SDK" stopped being true.**
  `SupabaseAuthService` said so and built its own client to make it so, with a comment
  explaining that a second client would be a second Keychain session and a second
  refresh loop. P1-F needs the network for two more things, so the client moved to
  `SupabaseStack` and the three consumers take it. The lock-in ADR 0003 accepted is
  unchanged in kind and still countable: three files, each behind a protocol.

### One thing the design had to choose against the artboards

`Var.dc.html` labels the confidence chips **CLEAR / TIGHT / UNSIGHTED**. The build
uses the copy deck's **HIGH / MEDIUM / LOW**. The language runs through the product
everywhere it costs nothing, and here it costs something: that chip is what tells
somebody which number to go and check, and "TIGHT" does not say that to anyone who
has not been told what it means. `DESIGN.md` records it, with the same tie-break the
Mode section already used — scanability outranks expression on every screen except
The Table.

### Three things the first device session found

Logged, corrected, and worth reading — the first two are the reason a device
session is not a formality.

**The portion screen was writing wrong calories.** It filled in `100 g` and the
catalogue's `kcal_per_100g`, then logged whatever was in the calories field — so
changing the portion to 200 g wrote 200 g of food at 100 g of energy. Silently,
with nothing on screen suggesting anything was wrong, into the twenty-one days
the entire ranking engine is designed against. `Food.kcal(forGrams:)` already
existed and was already tested; the screen simply never called it. The
arithmetic now lives in `PortionBasis` with its own tests, the portion drives
the derived numbers, and a line under the field says so — because a figure that
moves when you edit a *different* field, with nothing explaining it, reads as the
app being broken. **This is the standing rule's own case:** a change that breaks
a day's logging is a fix-now bug, and one that quietly halves it is worse than
one that stops it.

**Four routes wrote rows and nothing read them back.** The undo strip covered
only the last entry and vanished the moment anything else was logged, so a Squad
row tapped twice by accident was permanent — and §2.3's forty-eight-hour edit
window had been in the repository, tested, since P1-B with no surface at all. A
**Today** section now sits on the Sub On sheet between the team sheet and the
band: every log for the day, newest first, tap to correct the portion or remove
it, with the lock stated in the copy deck's words once the window closes. It is
deliberately not Matchday's team sheet, which is P1-H and a different screen
doing a different job.

> **Grouped by half, not by meal.** The Today list splits into First Half and
> Second Half, which is most of what a lunch-and-dinner breakdown would give and
> costs no column — the half is a pure function of `logged_at`. Whether Ninety
> grows real meal slots is a product decision with a migration behind it, and
> this is deliberately not a down-payment on one. Carried to the P1-H
> conversation, where the dashboard makes the question easier to answer.

**`--limit` was importing the wrong two hundred thousand foods.** A scan of a
real tin returned "no match for that barcode" with a working scanner and a full
`foods` table. Nothing was broken: `--limit` stops after N rows *in file order*,
the Open Food Facts export is ordered roughly by barcode, and a UK product is an
EAN-13 beginning `50` — millions of rows into a 3.9-million-row file. The flag is
a smoke test and now says so; `--country united-kingdom` is what builds a mirror
worth scanning against, and it is smaller as well as more relevant.

---

### Closed 9 September, on a device, against the live project

All four routes walked on a real phone. What that run actually established, and
what it did not:

| | |
|---|---|
| ⌘U | 175 tests green, across 19 suites. 71 of them new |
| Manual | A real meal logged, killed the app, still there on relaunch |
| Search | Resolves against 142,068 UK-tagged foods through `search_foods` |
| Barcode | A tin off the shelf resolves and fills in the portion screen |
| Photo | End-to-end round trip: capture → Storage → Edge Function → Under Review → confirmed. *"Works surprisingly well"* |
| The Squad | A food logged twice moves up and repeats on one tap |
| Migrations 005–006 | Applied to the live project |
| `estimate-meal` | Deployed, Gemini, with the daily cap live |

**Three things it did not establish**, listed because a device run is only worth
what it actually exercised:

- **Nothing has been logged with the radio off.** Manual is offline by
  construction and search degrades by design, but neither has been *seen* to.
  That is P1-I's airplane-mode day and the exit criterion stays open for it.
- **The photo latency was not recorded.** The spike measured 1.9–3.1 s
  server-side; the app measures it client-side with the upload included, and the
  difference is the interesting part. `Log.data` writes it on every estimate —
  it needs one Console read, not new code.
- **Sub On and Under Review have not been captured at `.xSmall` or
  `.accessibility5`.** Both ship the previews; nobody has looked at them. Same
  outstanding item P1-A carried into P1-H for Matchday.

---

### What the first build session cost, and what it caught

Seven rounds between "written" and "closed", which is the honest number and the
argument for not treating a written epic as a finished one. Five were the
environment; two were real defects the tests could not have found.

| Round | What |
|---|---|
| 1 | `PhotosPicker`'s `@ViewBuilder label:` is not `@MainActor` under Swift 6 — the only construct in P1-F that produced an isolation error. Replaced with the `.photosPicker` modifier |
| 2 | Nine `@ViewBuilder` attributes on the wrong line for SwiftLint's `attributes` rule, two four-member tuples, and a stored `static let [String: Any]` that is not expressible under Swift 6 |
| 3 | Two meal-period fixtures written in UTC when they meant local time. **The fixture, not `MealPeriod`** — the criterion's own test passed throughout |
| 4 | `SUPABASE_URL` pasted as the REST endpoint. The importer now normalises it, and the dry run — which had skipped the environment check entirely — now rehearses the thing the real run fails on |
| 5 | A python.org Python with an empty trust store. Named as a remedy rather than worked around: an unverified SSL context would downgrade the only thing protecting a service-role key in flight |
| 6 | **The portion screen was logging 200 g of food at 100 g of energy.** Found by using it. See above |
| 7 | `--limit` importing the wrong two hundred thousand foods — a working scanner against a full table that could not contain the tin |

Rounds 6 and 7 are the ones worth the session. Neither is reachable from a test
suite: the first needed somebody to type a number into a field and look at the
result, the second needed a real barcode on a real tin.

---

## P1-G — what landed

All four stories, 13 points, on branch `claude/weight-entry-impl-gfed70`.

**Compiled and green, 10 September.** Written the day before in a Linux container with no
Xcode, Swift toolchain or simulator; the first Mac session built it, ran the full suite
— **231 tests in 19 suites, all passing** — and launched the app. `Charts` and
`HealthKit` both compiled first time, which is not what the previous three epics'
caveats would have predicted.

**Two SwiftLint violations under `--strict`, and both were this epic's.** Neither was a
bug and both are recorded because the fix for each had a wrong version:

- **`SwiftDataRepositories.swift` hit 401 lines against a 400-line limit.** Extracting
  the shared `insert` helper for the batch import is what pushed it over. Split into
  `SwiftDataWeightRepository.swift` — the one repository of the four that actually grew.
  The wrong fix was trimming a comment until the number came down.
- **`WeighIn` and `Pace` wrote out their own memberwise initialisers.** Deleted;
  `unneeded_synthesized_initializer` is right. `BodyMassReading` keeps its init because
  that one carries a default value and is therefore not synthesised.

**Walked on a real device the same day — P1-G is closed.** The HealthKit authorization
sheet appears rather than the app trapping, which is the check that matters most because
missing usage strings crash at the call rather than failing it. The chart renders, the
reading list removes, a real weigh-in survives a rebuild, and both ends of the type scale
hold. Nothing about the epic is now written-but-unrun.

**This epic was not one thing, and the running order was right about it.** The
weight-entry surface was the day-0 half; the EWMA, the chart and the pace were always
able to land underneath a running clock, and in the end all four arrived together.

| Story | Outcome |
|---|---|
| Weight entry: manual plus HealthKit | ✔ Both routes land in `weight_logs` with `source` set. Manual is offline by construction — nothing on the path is `async`. `HealthKitBodyMass` is the only file in `Ninety/` that imports HealthKit; everything else works against `BodyMassSourcing`. ✔ walked on the phone: the authorization sheet appears, and an empty read reports "Nothing new in Apple Health" rather than guessing at a refusal |
| No duplicate when the same reading arrives both ways | ✔ `WeightReconciliation` — three filters, tested. Ninety's own samples by `HKSource`, the same instant, and the same day within 0.1 kg. ✗ still not exercised against a real scale — the three filters are proven against mocks only, and the cross-source case wants a smart scale to be sure |
| 7-day EWMA in Swift Charts | ✔ `WeightTrend`, pure, with 16 tests and 48 assertions covering gaps, day collapse, entry order and a timezone change. ADR 0020 records what the average is an average of. ✔ renders on the phone |
| One-point and no-point trend states | ✔ Four states, not three: zero, one, a handful, and a full week. `TrendReadiness` counts *reading days* rather than points, which is the distinction Spike A's one-point trend was about |
| Pace against the rate chosen at onboarding | ✔ Line derived from the S3-filtered rate on the profile, clamped at the S2-validated goal weight. Ahead is stated and never celebrated, with a test that says so by name |
| The Run, as a screen | ✔ Headline, chart, range selector, legend, pace panel, reading list with removal, Apple Health section — rendered on a real phone, and holding at both ends of the type scale |

**Three things worth reading, and one of them is a gap rather than a win.**

- **The trend runs on calendar days, not on readings — [ADR 0020](../decisions/0020-trend-smoothed-over-calendar-days.md).**
  The two readings of "7-day EWMA" agree exactly when the user weighs in daily, which is
  why the difference is easy to miss: the divergence only appears in the data of somebody
  who skipped a day, which over 21 days is everybody. Smoothing the array makes α a
  function of how often the user remembers, so the chart ends up measuring the habit
  rather than the body.
- **A mistyped weight has no 48-hour lock on it, and that asymmetry with `food_logs` is
  deliberate.** §2.3's window exists because an editable food log is a way to rewrite a
  scored week. A weight is a measurement of a body; `7.84` typed for `78.4` is inside the
  column's bounds, and the EWMA has no way to shrug it off — it drags every trend value
  after it for as long as it is stored. So the readings list can remove anything, and the
  entry screen shows the last reading under the field, which is §2.3's own preference
  (*flag, do not reject*) applied to entry rather than to scoring.
- **The pace verdict does not say how thin its evidence is, and it should.** Two readings
  a fortnight apart produce a trend that sits almost exactly on the pace line whatever the
  two numbers are, because one α-step moves it by a quarter of the gap — so a user who
  weighs twice a month is told "tracking inside your pace" more or less regardless. The
  arithmetic is right; somebody with two readings has no trend that can be ahead or behind
  anything. The screen is what is wrong: `TrendReadiness` already distinguishes the four
  cases and the pace panel does not read it. **Not fixed here**, because the fix is a
  designed state rather than a condition, and it is written up in ADR 0020 rather than
  left to be found.

**Two things this epic deliberately did not do.**

- **It is not P1-E.** Body mass is a handful of discrete samples a week, each with its own
  instant; steps and active energy measured ~1,830 and ~3,000 samples *per day* on a real
  device, which is the whole reason P1-E must use `HKStatisticsCollectionQuery` and a
  persisted anchor. A statistics query over body mass would average a day's weigh-ins
  inside HealthKit and return a number with no timestamp — which is exactly what the
  duplicate check needs. No anchor is shared, and the sync window is bounded by the last
  reading held.
- **It does not write to Apple Health.** The share set is empty and
  `NSHealthUpdateUsageDescription` says so plainly. Writing manual entries back would put
  a second copy of Article 9 data somewhere the user did not ask Ninety to put it, and no
  acceptance criterion asks for it. The duplicate filter for Ninety's own samples is in
  place anyway, inert rather than wrong, so the day that changes is a change to one array.

**One thing this epic did not close, and it is a real one.** The cross-source duplicate
case — a smart scale writing to Apple Health while the same weigh-in is typed into Ninety
— is proven against mocks and has never met an actual scale. `WeightReconciliation`'s
0.1 kg tolerance is a judgement about how two devices round the same body, and the only
thing that can check it is two devices. Named here rather than counted as done.

**And one piece of infrastructure that is now permanent.** The HealthKit capability is
enabled on the App ID at developer.apple.com, the same out-of-repo step P1-C needed for
Sign in with Apple. A fresh clone still builds without it; a fresh *signing identity*
does not, which is why it is in the runbook rather than only in a commit.

---

## P1-I — what landed

Both stories, 8 points, on branch `p1-i`.

**Closed 10 September, on a real phone, with the radio off.** Written the same day in a
Linux container with no Xcode, Swift toolchain or simulator; the Mac session built it,
ran the suite — **270 tests in 21 suites, all passing** — and the day was walked on the
device including a spell in airplane mode that reconciled on reconnect. That last part is
the exit criterion, and it is the only part a suite could not have given: the whole point
of ADR 0005 is that a list of meals looks identical whether or not sync worked.

**One compile error and one test failure**, both recorded below, and neither in the
drain's logic. The second one is the more useful of the two and was not even in this
epic's code.

**The Linux linter earned its place, and so did the Linux checks.**
`check_schema_parity.py` now reads the drain's columns against migration 001 and every
enqueued table name against `SyncTable`; both pass without a Mac. `swiftlint-static`
caught seven `--strict` violations before the first build. What none of them could catch
was the one thing that did fail, which is the point of the section below.

**The gap this closed is not "sync was slow", it is "sync did not exist".** Every write
in the app has left a note in `sync_outbox` since P1-B, and nothing had ever read one.
Three weeks of the only irreplaceable asset in the project were on one phone, and the
`OutboxEntry.attempts` column had never been incremented because nothing had ever
attempted anything.

| Story | Outcome |
|---|---|
| Outbox and the sync service | ✔ `Ninety/Sync/` — the plan, the payload, the PostgREST client, the service and the panel. Every mutation already enqueued; this drains it. Idempotent by construction: ids are minted on the device, so every write is an upsert and a replayed payload resolves to the row it already wrote. Backoff doubles from 2s to a 5-minute ceiling and is cancelled by a reconnect. `attempts` is honoured — five refusals and the row parks. The last-write-wins limitation is in ADR 0005 and now in [ADR 0021](../decisions/0021-outbox-drains-one-plan-per-row.md), which is what a future reader will actually find. ✔ compiled, green, and run on the device |
| Airplane-mode verification | ✔ **Done on the phone, 10 Sep.** A day used with the radio actually off, reconciled on reconnect. The criterion's own wording rules out the synthetic version — *"gyms and restaurant basements have no signal, this is the scenario"* — so this is the one story in the epic that no amount of test coverage could have closed |

**The one compile error: a formatter that cannot be shared.** `SyncTime` held a
`static let ISO8601DateFormatter`. That is an `NSFormatter` subclass — a class, not
`Sendable` — so a shared one is exactly the mutable static `SWIFT_STRICT_CONCURRENCY =
complete` refuses. Both obvious repairs are worse than dropping it: an instance per call
allocates a formatter to print six columns, and a lock around a shared one is a mutex
protecting a date. `SyncTime` had already hand-rolled `yyyy-MM-dd` to avoid
`String(format:)` reading `%d` as a 32-bit width against a 64-bit `Int`, so the instant
went the same way and the file now holds no shared state at all. It gained precision on
the way: microseconds rather than milliseconds, which is what `timestamptz` stores and
what `weight_logs` resolves its upsert against.

**The one test failure was not in this epic's code, and it is the more interesting of
the two.** `FoodSearchTests.noMatchAnywhere` — a P1-F test, untouched, passing since 9
September — started failing. Nothing about search changed. What changed is the *timing
environment*.

`FoodSearchModel` debounces the catalogue call by 250 ms of real time. The tests slept
600 ms and asserted afterwards, leaving 350 ms of slack for the debounce task to be
scheduled and finish. Both the model and this epic's 39 new tests are `@MainActor`, and
several of the new ones build in-memory `ModelContainer`s — they ran at 0.7–1.2 s each
and held the MainActor exactly while the debounce was waiting for it. The headroom went.
The test's own comment had called the interval *"long enough not to be flaky on a loaded
machine"*, which was a guess, and adding tests falsified it.

**The fix is not a longer sleep.** A sleep that is long enough is not a fix, it is a
longer bet, and the next epic would collect on it again. `FoodSearchModel` gained
`settle()` — it awaits the pending task — and all five sleeps in the suite became
`await model.settle()`. It still costs the debounce, because the debounce is the thing
under test; what it no longer costs is a guess about how busy the machine is. **There is
now no `Task.sleep` anywhere in `NinetyTests/`**, which is worth keeping true.

The general lesson is worth more than the fix: **a test suite that waits on a wall clock
gets more fragile every time the suite grows.** It is a cost that arrives on somebody
else's ticket, in somebody else's file, looking like a bug they caused.

**Seven SwiftLint violations under `--strict`, all this epic's, all fixed before the
first build — found on Linux.** `CONTRIBUTING.md` documents `swiftlint-static`, which runs on
Linux with no Swift toolchain and skips only the `custom_rules` block (those need
SourceKit). It had never been used in this repo, and it earned its keep immediately: on a
machine that cannot compile a line of Swift it caught every structural violation that
would have failed the macOS job. **Run it before every push from a container.** What it
found:

- **`RootView.swift` hit 420 lines against a 400-line limit** once the sync service was
  threaded through it. `MainTabView` and its previews moved to `Ninety/App/MainTabView.swift`
  — the same split P1-G made for `SwiftDataWeightRepository`, and the same wrong fix
  avoided: trimming comments until the number comes down.
- **`optional_data_string_conversion`, four times.** `String(decoding:as:)` is
  non-failable and substitutes replacement characters. In `SyncRow` that would have put
  them inside a `jsonb` column, so the rule was right about more than style — the
  failable initialiser is there now, falling back to `{}` rather than a JSON `null` that
  `model_output`'s `not null` would refuse forever.
- **Two closures, one of them trailing**, on the Sub On sheet once `onDismiss` arrived.
  `MatchdayView` already carries the note: with more than one closure, a reader has to go
  and look up which parameter the braces landed on.
- **`@ViewBuilder` on its own line above a *variable*.** The rule wants attributes on
  their own line in functions and types, and on the same line as variables.

**Four decisions, all in [ADR 0021](../decisions/0021-outbox-drains-one-plan-per-row.md),
and the third is the one the clock forced.**

- **One plan per row, not one request per entry.** A meal logged on the Underground,
  corrected at the barrier and corrected again on the bus is three outbox entries and one
  write, read from the current local row at drain time. `Outbox.enqueue` promised exactly
  this in P1-B and wrote `{}` as its payload on the strength of it.
- **Upserts in dependency order, deletes in the reverse.** `food_logs.food_id` references
  `foods` and `photo_estimates.log_id` references `food_logs`, so a batch sent in the
  order the user made it violates a foreign key roughly whenever somebody adds a custom
  food and logs it.
- **Only a refusal of the row costs the row an attempt.** No network, no session, a 5xx
  or a 429 stops the drain where it is and charges nothing to anything. This is not
  tidiness: a week logged on a plane would otherwise spend five attempts per row on an
  aeroplane and land at the gate already parked, which is the clock's failure mode
  written as a retry loop.
- **Five refusals and it stops asking, visibly.** Parked, kept, counted, and shown in
  `Settings → Sync` with a control that resets the count. `OutboxEntry`'s own doc comment
  asked for this in P1-B — *"so a row that fails forever can be found rather than retried
  silently until the end of time"* — and this is the first code that could honour it.

**Two writes are dropped on purpose rather than sent**, both logged by name so a queue
that empties without sending anything can be explained afterwards. A queued insert whose
local row has gone describes something that does not exist — created and deleted offline,
or cascaded away with its parent. And a correction to a `food_logs` row that reaches the
front of the queue after §2.3's 48-hour window has closed is dropped rather than sent to
be refused five times: the rule is what bounds the conflict window in the first place, and
ADR 0005 already counted that as a happy side effect.

**One surface, and it is an instrument rather than a feature.** `Settings → Sync` says
where the day's logging currently is: up to date, *n* changes waiting, sending, or *n*
still here with a way to ask again. It exists because "reconciled cleanly on reconnect"
is not visible in a list of meals — the whole point of ADR 0005 is that the list looks
identical either way — so the airplane-mode day needs somewhere to read the answer off.
Deliberately the only place: a count of unsent rows on Matchday would be the network
leaking into the screen someone opens to log breakfast.

**Three things this epic deliberately did not do.**

- **It does not pull.** The outbox is a push, so the server copy protects the 21 days
  against a lost phone and does not yet repopulate a new one. `RootView` has said since
  P1-C that a reinstall would stop asking for consent twice once P1-I landed; half of that
  is now true — the timestamp reaches Postgres — and the comment has been corrected rather
  than left reading as a claim about what the code does. Last-write-wins against a device
  holding no rows is indistinguishable from a wipe, which is why a restore is a separate
  decision and not a follow-on commit.
- **It does not send `updated_at`.** ADR 0005 resolves conflicts by *server* timestamp
  and migration 001 is emphatic about the word: a client-supplied one lets a device with a
  wrong clock win every conflict. The `set_updated_at` trigger owns the column and the
  payload does not mention it.
- **It does not send `hk_anchor`.** An anchor describes what *one device* has already
  read. Pushing it to a second phone would tell that phone it had read a history it has
  never seen, which is the exact failure §1.4 calls "the entire trick" for avoiding.

**Two things this epic leaves open, neither blocking, both named rather than discovered
later.**

- **A late delete leaves the two stores disagreeing.** A `food_logs` delete that arrives
  after the 48-hour window returns 204 with nothing removed — RLS `using` clauses filter
  rows rather than raising — so the phone forgets the row and the server keeps it. The
  drain cannot tell, and treating a successful response as a failure would retry forever.
  Phase 2 reads its test set from the phone, so it costs nothing today. It becomes real
  the first time anything reads the *server* copy as authoritative, which is the same day
  the pull half gets built.
- **There is no restore.** Stated above as a deliberate omission, and repeated here
  because it is the thing most likely to be assumed working. The 21 days are now backed
  up against a lost or replaced phone — which was the actual risk — but a reinstall
  starts from an empty store and asks for Article 9 consent a second time. Phase 3 at the
  earliest, and it needs its own conflict story: last-write-wins against a device holding
  no rows is indistinguishable from a wipe.

**What closing this epic changed about the risk.** Before 10 September, three weeks of the
only irreplaceable asset in the project lived on exactly one phone, and the standing rule
about a broken day's logging costing three weeks was true with no mitigation behind it. It
is still true — but the cost of a dropped phone is now a phone rather than the phase.

---

## P1-H — what landed

Four stories and one task, 14 points, on branch `p1-h-matchday`.

**Written 10 September. NOT YET COMPILED**, and that caveat is the most important line in
this section. Every line of it was produced in a Linux container with no Xcode, no Swift
toolchain and no simulator — the same position P1-A was in for six days, and the same
rule applies: **the epic is not closed until a Mac has built it, run the suite and
rendered it on a phone.** Everything that *could* be checked without a toolchain has
been, and is marked as such below.

| Story | Outcome |
|---|---|
| Band and remaining, on the pitch | ✔ `MatchdayView` + `PitchMeter`. One figure, its tolerance, and where the day sits. The figure goes negative rather than clamping, the eyebrow changes and the colour does not, and the band renders as `1,850 ±100`. The pitch runs a whole band's width past the box so a day over it has somewhere to be. ✗ never rendered |
| Macro split | ✔ `MacroTotals` + `MacroPanel`. Scaled through `PortionBasis`, never through arithmetic in a view. Says what fraction of the day it covers. Tested at zero logs, one and twenty. ✗ never rendered |
| Weight sparkline | ✔ `WeightPanel`. The same `WeightTrend` The Run builds, from the same repository — one calculation, two renderings, asserted by a test that compares the two models' `latestTrendKg`. Reads `TrendReadiness`, so the one-point state is designed rather than defaulted. ✗ never rendered |
| Form: the 7-day consistency ring | ✔ `Form` + `FormGuide`. Seven segments always, calendar days in the user's own calendar, filled or hollow. No cross, no colour-only signal, no animation on the transition. ✗ never rendered |
| Division badge placeholder | ✔ `DivisionSlot`. A `HoldingNote` with no tier in it, the same two strings The Table uses, and absent entirely under the §10 S6 opt-out. ✗ never rendered |

**The parked product question is answered, and it turned into a schema change.**
[ADR 0022](../decisions/0022-meals-are-slots-derived-and-overridable.md): meals are real
slots — breakfast, lunch, dinner — **derived from `logged_at` by default and stored only
where the user corrects the derivation.** Migration 007 adds a nullable `meal_slot` enum
to `food_logs`; `MealPeriod` is deleted.

The shape is the part worth remembering. **No logging route asks which meal it is**, so
logging costs exactly the taps it did yesterday — which is the clock's constraint rather
than a convenience, because a required field on the write path would spend the one thing
this phase cannot compress on a label. The column exists so the derivation can be wrong:
a night shift, a very late dinner. And a slot is written **only** where it disagrees with
what the app would have derived, so `null` keeps meaning "the app worked this out" rather
than decaying into "nobody has looked".

### What the schema change cost, and what it caught

- **The local store goes to V2.** `NinetySchemaV2` adds one optional property to one
  model with a lightweight stage. This is the first schema change to land on a phone that
  already holds logged days — precisely the case `NinetySchemaV1`'s own note was written
  for — and it is the cheapest shape such a change can have: nil already means what every
  existing row means, so there is nothing to backfill and no custom stage with anything to
  do. **This is the highest-risk line in the epic for the clock** and the first thing the
  Mac session should check: launch onto a store that already holds days, and confirm they
  are all still there.
- **`check_schema_parity.py` was reading one file and calling it the schema.** It had been
  right until now: everything lived in migration 001. It would have reported `meal_slot` as
  a column the drain sends that does not exist — a false failure, from a checker whose whole
  job is to be trusted. It now concatenates every migration in filename order and folds in
  `alter table … add column`. ✔ green on Linux, 12 checks.
- **RLS needed no change, and the migration says so rather than leaving it to be assumed.**
  The four `food_logs` policies are row-level, so a new column is covered the moment it
  exists. §2.3's 48-hour lock covers it for the same reason — the lock is on the log, and
  the slot is part of the log. There is a test for that.

### Three things the build had to choose, and what it chose

- **The Form ring against the artboard's bars.** `Main.dc.html` draws seven bars; the
  ticket says ring. It is a ring **of seven discrete segments**, which is both. A single
  sweeping arc was rejected for the reason a streak counter is: it reads as a quantity of
  progress that can be lost, and this is a count of days that can only be added to.
- **The macro panel's honesty against a tidier layout.** Macros live on the `foods` row a
  log points at, and three of the four routes can produce a log without one — a quick add
  by calories has none by construction. So the panel carries `From 3 of 5 items` rather
  than presenting a partial total as a whole one. It is the least tidy thing on the screen
  and the only version of it that is true.
- **`STILL TO PLAY WITH` against the copy deck's `CALORIES REMAINING`.** The world's
  vocabulary wins where it costs nothing, and this costs nothing. Recorded in `DESIGN.md`
  alongside the two deviations that were settled the other way.

**One thing the deck had wrong, now fixed.** §3 wrote the dashboard's band as
`of 1,750–1,950 band` — the dash form — in the one document that is meant to be the source
for the strings that rule is about. `DESIGN.md` § Numbers and
`SafetyCopyTests.rangesAreNeverDashed` both say a range is a figure and a tolerance. The
deck says so now too.

### What a Mac session has to do before this closes

1. **⌘U.** 25 new tests across `MatchdayTests`, `FormTests` and `MealSlotTests`, plus the
   S5 sweep over `MatchdayCopy`. Nothing in this epic has ever been compiled.
2. **Launch onto a store that already has days in it**, not a fresh install. The V2
   migration is the one change here that can lose data, and a fresh simulator will not
   exercise it.
3. **Apply migration 007** to the live project, then log a meal and correct its slot with
   the radio on — the column has to survive the round trip, and the drain has never sent
   an enum that can be null.
4. **Capture Matchday at `.xSmall` and `.accessibility5`.** Both previews exist by name.
   This has been outstanding since P1-A and P1-H is the epic that can finally clear it.
5. **Walk a day.** The screen is a dashboard, and a dashboard that has never been looked
   at during an actual day is a layout.

**What this epic does not touch, deliberately.** Nothing on Matchday mentions or waits on
the network — `MatchdayModel` has no reference to `SyncService`, which is P1-I's
constraint on this epic honoured as a dependency graph rather than as a comment. And the
pace panel's thin-evidence gap that P1-G left open is **still open**: it is on The Run,
not here, and widening this epic to fix it would have put an unbuilt change into a second
screen. Matchday's own weight panel reads `TrendReadiness` from the first commit, so it
does not repeat the mistake.

---

## Out of scope, and where it went

| | |
|---|---|
| Open Food Facts + USDA mirror | ~~Moved out of P1-B to land with P1-F's search route.~~ **Landed and loaded with P1-F, 9 Sep** — 142,068 UK-tagged rows via `scripts/import_food_mirror.py`, searched through the ranked `search_foods` function |
| Ranking maths, tiers, anti-gaming | Phase 2. `Packages/RankingEngine` is scaffolded now only so the lint purity rules have a boundary to police |
| The scoring half of S3 | Phase 2 — progress score peaking at target rate |
| The photo-accuracy benchmark | **Deferred 8 September, no date.** `spikes/vision-accuracy` needs 20 **weighed** meals, and that assumes cooking and portioning everything yourself — it does not survive eating out or being cooked for, which is most real meals. It is explicitly not a gate (the harness README: *"Whenever. Not a gate."*) because the estimate is always presented as a helper with ranges and one-tap correction, so a missing number changes nothing that ships. Picked up when there is a run of meals it can honestly be built from |
| Privacy policy, export, deletion, S7 triggers | Phase 3, before the first external tester |
| Friends and leaderboards | Phase 4 — but their two tables ship empty in migration 001, because retrofitting relationships hurts |
| PostHog | Phase 3 |
| Workout logging or UI | ADR 0009. Workouts are read passively and never surfaced |

---

## First Mac session — happened 8 September 2026

**It closed P1-A, un-blocked P1-B and P1-C, and found four bugs no compiler could
have.** Kept below as the runbook, because every fresh clone still needs it.

In order, and stop at the first failure — each step is the precondition for the next.

```bash
git config core.hooksPath .githooks          # once per clone
brew install swiftlint xcbeautify
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then add your team id,
                                             # SUPABASE_HOST and SUPABASE_ANON_KEY

python3 design/tokens/generate.py --check    # tokens, contrast, fonts
scripts/verify-guardrails.sh                 # now runs the SwiftLint half too
swift test --package-path Packages/RankingEngine

open Ninety.xcodeproj                        # resolve packages, ⌘B, ⌘U, run on the phone
```

**Four things specific to P1-C, in this order.** Each is a precondition for the
next and three of them are outside the repo, so none of them can be checked from
a commit.

1. **Xcode resolves `supabase-swift`** on first open. Commit the
   `Package.resolved` it writes — `.gitignore` says an app pins its dependencies.
2. **Turn on Sign in with Apple for the App ID** at
   developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
   `app.ninety.Ninety` → Capabilities. `Config/Ninety.entitlements` asks for it;
   the capability has to exist on the identifier or signing fails.
3. **Enable the Apple provider in Supabase** — Authentication → Sign In / Providers
   → Apple → on, and put the **bundle id** `app.ninety.Ninety` in the *Client IDs*
   field. This is the step with no error message worth reading: without it the
   token exchange is rejected for an unacceptable audience, and the app shows
   "Ninety couldn't finish signing you in", which points at the app rather than at
   a dashboard toggle. A native-only flow needs nothing else there — no Services
   ID, no key, no secret. Those are for the web flow.
4. **Fill in `Config/Local.xcconfig`** — Supabase dashboard → Project Settings →
   Data API for the host (drop the `https://`), and the *publishable*
   `sb_publishable_…` key, never the secret one.

**`DEVELOPMENT_TEAM` is now required for a Simulator build too.** It was
previously only needed for a device. An entitlements file asks the signing
machinery for a capability, and automatic signing resolves that against a real
team whichever destination you build for.

**Then sign in.** On a real device rather than the Simulator the first time —
Simulator sign-in works but needs an Apple Account signed in under its own
Settings, and it fails in ways that look like app bugs. Console should carry
`Signed in with Apple.` under the `auth` category. Force-quit and reopen: it should go straight past the sign-in screen
(`Session restored; refresh handled by the SDK.`), which is the cold-launch
restore the ticket asks for.

**The consent row will not be in the Supabase dashboard, and that is correct.**
It is written to SwiftData and enqueued in `sync_outbox`, and nothing drains
that outbox until P1-I. Check it locally instead — a `Profile` fetch in the
debugger, or delete and reinstall the app: a reinstall should ask for consent
again, because the row went with the store. Two timestamps, and they are not
equal unless you tapped both switches inside the same second.

> **Stale from 10 September, and kept as the record of what the check was.**
> P1-I drains the outbox, so the consent row *does* now appear in the dashboard.
> A reinstall still asks again — the drain is a push and nothing reads a row back
> down — so the second half of the check is unchanged.

**What to look at, specifically.** Console should carry
`Bundled faces registered: 7` from `BrandFont.verify()`. If it says they did *not*
register, the text is silently San Francisco and the Matchday world is gone — check
`UIAppFonts` in `Config/Info.plist` against the target's Copy Bundle Resources phase.
Then Settings → Display & Text Size → Larger Text, drag it to the maximum, and come back:
nothing should truncate or overlap.

**Then record it.** Tick the P1-A ticket with what actually built rather than what was
meant to, per the repo convention on closing criteria on different evidence.

### Two chores that session left open

Neither blocks anything; both are the sort of thing that is annoying to discover later.

- **`Package.resolved` is not committed.** `.gitignore` says an app pins its
  dependencies, and this one does not yet — so CI and a second machine could resolve a
  different `supabase-swift` to the 2.55.1 that was verified. Find it with
  `find Ninety.xcodeproj -name Package.resolved`, then commit it.
- **`DEVELOPMENT_TEAM` in `Config/Local.xcconfig` holds a team *name*, not the
  10-character Team ID.** Automatic signing works around it while there is one team on
  the account, and stops working around it the moment there is not.

---

## Handoff prompt for a fresh session

> I'm on Phase 1 (Single-Player Core) of Ninety. Building food logging, weight tracking,
> HealthKit sync, and the Matchday dashboard. Architecture: SwiftUI + `@Observable`
> ViewModels + protocol-based repositories, SwiftData local store with an outbox pattern
> syncing to Supabase.
>
> Currently working on: **P1-H, the Matchday dashboard — written, and the next session is
> the one that builds it.** Everything below is verified on a real device against the live
> project as of 10 September *except P1-H itself*, which was written in a Linux container
> with no Xcode and has never been compiled. Where something is written and not yet run, it
> says so.
>
> P1-A is closed: the project builds, the type decision is ADR 0015 (Dynamic Type, two
> bundled faces), the shell is three tabs with Sub On as a sheet, and `DESIGN.md` is the
> authority on how the world is built. P1-B is closed: migrations applied, RLS proven
> with two accounts, SwiftData models and repositories green, and the food mirror loaded
> — 142,068 UK-tagged foods. P1-C is closed: Sign in with Apple is the only identity
> route (ADR 0016), and the app will not start until Article 9 health consent is recorded
> separately from terms acceptance (ADR 0017). Every repository is built from the
> signed-in user's id via `Repositories.live(context:userID:)`.
>
> **P1-D is closed.** Onboarding, the band, S1–S7 as types in `Ninety/Safety/`, the
> seven-day calibration window (ADR 0018) — and **there is a Settings screen**: a sheet
> from Matchday's masthead carrying the competitive opt-out, the support signposting,
> both consent switches and sign out, in that order.
>
> **P1-F is closed (9 Sep).** All four logging routes walked on a real phone: manual,
> search against the mirror, barcode off a real tin, and photo end-to-end through the
> `estimate-meal` Edge Function to the mandatory Under Review screen. Plus the Squad and
> the Bench, a Today list with correction and removal inside §2.3's 48-hour window, and
> the per-user daily photo cap enforced server-side. 175 tests, 19 suites.
>
> **P1-G is closed (10 Sep).** All four stories, walked on a real phone: weight entry
> from the keyboard and from Apple Health, the 7-day EWMA in Swift Charts, the zero /
> one / handful / full-week states, and the pace against the S3-filtered rate. The Run is
> a real screen, `Ninety/Health/` holds the one `import HealthKit` in the app, and ADR
> 0020 settles what the average is an average of — the series runs on calendar days, not
> on readings, so the chart measures the body rather than the weighing habit. 231 tests,
> 19 suites.
>
> **P1-I is closed (10 Sep).** `Ninety/Sync/` is the first code that
> ever reads `sync_outbox`: one plan per row, dependency order on the way up and the
> reverse on the way down, upserts so a replay cannot duplicate, backoff on the
> connection, and five refusals before a row parks. [ADR 0021](../decisions/0021-outbox-drains-one-plan-per-row.md)
> settles the policy, and the one rule to hold on to is that **only a refusal of the row
> costs the row an attempt** — a week logged on a plane must not land at the gate already
> parked. `Settings → Sync` is the only surface, and it is the instrument the
> airplane-mode day was read off — a real day with the radio off, reconciled on
> reconnect, which closed the exit criterion. 270 tests in 21 suites.
>
> **Two things P1-I leaves open, neither blocking, and one of them is a trap.** It does
> not *pull*: the 21 days are backed up against a lost phone, but a reinstall starts from
> an empty store and asks for Article 9 consent a second time. And a `food_logs` delete
> arriving after the 48-hour window is refused server-side by an RLS `using` clause, which
> filters rather than raises — so the phone forgets the row and the server keeps it. Both
> are written up in ADR 0021. **The two rules P1-H had to not break, and did not:** no
> surface outside `Settings → Sync` mentions the network — `MatchdayModel` has no reference
> to `SyncService` at all — and nothing on any tab waits on it.
>
> **P1-H is written and unbuilt (10 Sep).** All four stories and the task: the band and the
> pitch, the Form ring, the macro split with its coverage line, the weight sparkline off the
> same `WeightTrend` The Run draws, the division placeholder, and the team sheet grouped by
> meal. It answers the parked product question as
> [ADR 0022](../decisions/0022-meals-are-slots-derived-and-overridable.md) — real meal
> slots, derived by default, stored only when corrected — which brings migration 007, a
> nullable `meal_slot` enum, and the local store's first version bump to V2. **Nothing in
> it has been compiled and migration 007 is not applied to the live project.** The Mac
> session's checklist is in the P1-H section above; the first item is launching onto a
> store that already holds days.
>
> **⏱ THE CLOCK IS RUNNING. Day 1 was 9 September; day 21 is 29 September at the
> earliest.** This changes what "done" means for every remaining epic: *a change that
> breaks a day's logging is a fix-now bug by definition*, because it resets a counter
> that costs three weeks to rebuild. Before you ship anything, ask what it does to
> tomorrow morning's log. **P1-H is written and not yet built** — the Matchday dashboard,
> the last screen that was a holding note. It exists as code and has never been compiled,
> so the next session is a Mac one and its checklist is in the P1-H section above. Four of
> the seven exit criteria are closed; what remains is P1-H's device run, P1-E's HealthKit
> sync, and the days themselves.
>
> **P1-H carries one change that can lose data, and it is the thing to check first.** The
> local store goes to V2 for `food_logs.meal_slot` ([ADR 0022](../decisions/0022-meals-are-slots-derived-and-overridable.md)),
> with a lightweight migration stage and nothing to backfill. Launch it onto a store that
> already holds logged days rather than a fresh simulator, and confirm they are all still
> there before anything else.
>
> **One thing P1-H leaves open, and it is inherited rather than new.** The pace panel on
> The Run still does not say how thin its evidence is (below). Matchday's own weight panel
> reads `TrendReadiness` from the first commit, so the dashboard does not repeat it — but
> the fix on The Run was deliberately left out of this epic rather than widening an unbuilt
> change into a second screen.
>
> **Two things P1-G left open, neither blocking.** The cross-source duplicate rule
> (`WeightReconciliation`, 0.1 kg tolerance) is proven against mocks and has never met an
> actual smart scale. And the pace verdict does not say how thin its evidence is: two
> readings a fortnight apart sit on the pace line whatever they say, so a sparse weigher
> reads "tracking inside your pace" regardless. `TrendReadiness` already distinguishes the
> four cases; the pace panel does not read it. The fix is a designed state, not a
> condition.
>
> **Two things P1-F left open, neither blocking:** the
> photo latency has not been read out of `Log.data` yet; and Sub On and Under Review have
> not been captured at `.xSmall` or `.accessibility5` — The Run has, so the capture debt
> is now three screens rather than four.
>
> **The product question parked for P1-H is answered.** Ninety has real meal slots —
> breakfast, lunch, dinner — derived from `logged_at` by default and stored only where the
> user corrects the derivation ([ADR 0022](../decisions/0022-meals-are-slots-derived-and-overridable.md)).
> Migration 007 adds a nullable `meal_slot` enum to `food_logs` and `MealPeriod` is gone.
> No logging route asks the question, so logging costs the same taps it did; the column
> exists for the row the clock gets wrong. **Migration 007 has not been applied to the
> live project yet** — that is on the Mac session's list along with everything else.
>
> Requirements: offline-first (the UI never waits on network), RLS on every table, photo
> estimates always show ranges + confidence and require user confirmation. Ranges render
> as a figure plus a tolerance, never two numbers joined by a dash. The portion drives
> the calories, never the reverse. The safety rules in `docs/safety/` are Phase 1
> requirements, not Phase 3 polish. Design tokens are generated — edit
> `ninety.tokens.json`, never the Swift.

The board is the source of truth for *what is next*; this file is the source of truth for
*what closes the phase*.
