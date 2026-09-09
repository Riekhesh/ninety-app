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

**Two things the minimum set gets wrong as written**, found closing P1-D:

- **Weight entry is a blocker and is not built.** Onboarding writes one `WeightLog` and
  The Run is a holding screen, so there is no way to record tomorrow's weight. P1-J's own
  criterion is "real food, **real weight**", so a weight-entry surface is part of day 0,
  not part of P1-G's chart work.
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

- [ ] **21 consecutive days of real data logged** — non-negotiable, and the phase's actual purpose
- [ ] **All four logging routes work, offline included** — **the four routes are done and walked on a device (P1-F, 9 Sep); the "offline included" half is not.** Manual is offline by construction and search degrades to the phone's own foods by design, but neither has been exercised with the radio actually off, and nothing drains the outbox yet. That half belongs with P1-I's airplane-mode day and is deliberately not ticked here — the criterion says *offline included* and half a criterion is not a closed one
- [ ] **HealthKit incremental sync with a persisted anchor** — proven the way Spike A proved it: 56,764 samples on a first read, ~0 on the next
- [ ] **Weight trend rendering as a moving average** — 7-day EWMA; raw daily weight is never the primary series. **Written 9 Sep (P1-G) and deliberately not ticked**: `WeightTrend` is the EWMA, the raw series is off by default behind a toggle, and 51 tests across three new suites cover the maths — but nothing has rendered a `Chart` yet, and this criterion is about what the app *shows*. It closes on a device, on a screenshot
- [ ] **Outbox sync verified in airplane mode** — a real day with the radio off, reconciled cleanly on reconnect
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
| **P1-G** The Run: weight & trend | **All four stories written, 9 Sep — not yet compiled.** Weight entry (manual + Apple Health), the 7-day EWMA in Swift Charts, the zero/one/handful/week states, and the pace against the S3-filtered rate. ADR 0020 settles what the average is an average of | Medium |
| **P1-H** Matchday: the Today dashboard | Band, macros, sparkline, Form ring, division placeholder | High |
| **P1-I** Offline-first sync | Outbox, last-write-wins, airplane-mode verification | High |
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
5. **Kick off.** ~~Manual food entry~~ **done — P1-F, 9 Sep** — and ~~a weight-entry
   surface, which is the one thing still missing~~ **written — P1-G, 9 Sep, and not yet
   compiled.** Record day 1 the moment a Mac has built it and a phone has recorded a
   real weigh-in; the clock does not start on a commit.
6. **Everything else, underneath a running clock**, in this order: **P1-G · P1-I · P1-H
   · P1-E**, then P1-J and P1-X. Sync is second rather than
   last for two reasons: three weeks of the only irreplaceable asset in the project
   currently live on one phone with nothing draining the outbox, and the airplane-mode
   criterion needs real logging days to reconcile, so it has to happen *during* the clock.
   HealthKit is late because it is retroactive — a first read pulls the history back
   whether it lands on day 4 or day 18.

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

**Still outstanding:** Matchday captured at `.xSmall` and `.accessibility5`. Matchday is
P1-H, so there is no dashboard to photograph yet — the mechanism and the harness exist
(every view ships an `.accessibility5` preview; `DesignSystemTests.typeScales` asserts
all sixteen styles respond to the content size category). Carried into P1-H.

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

All four stories, 13 points, on branch `claude/weight-entry-impl-gfed70`. **Written, not
yet built:** every line was produced in a Linux container with no Xcode, Swift toolchain
or simulator. That caveat has now been carried by four epics in a row and has been worth
carrying every time — the first ⌘U on P1-B found `OutboxEntry.entity`, which broke every
write in the app and which nothing but running it could have found.

**This epic is not one thing, and the running order says so.** The weight-entry surface
is day 0; the rest lands underneath a clock that is already counting.

| Story | Outcome |
|---|---|
| Weight entry: manual plus HealthKit | ✔ Both routes land in `weight_logs` with `source` set. Manual is offline by construction — nothing on the path is `async`. `HealthKitBodyMass` is the only file in `Ninety/` that imports HealthKit; everything else works against `BodyMassSourcing`. ✗ never rendered, and no HealthKit call has ever executed |
| No duplicate when the same reading arrives both ways | ✔ `WeightReconciliation` — three filters, tested. Ninety's own samples by `HKSource`, the same instant, and the same day within 0.1 kg. ✗ never exercised against a real scale |
| 7-day EWMA in Swift Charts | ✔ `WeightTrend`, pure, with 16 tests and 48 assertions covering gaps, day collapse, entry order and a timezone change. ADR 0020 records what the average is an average of. ✗ no `Chart` has ever rendered |
| One-point and no-point trend states | ✔ Four states, not three: zero, one, a handful, and a full week. `TrendReadiness` counts *reading days* rather than points, which is the distinction Spike A's one-point trend was about |
| Pace against the rate chosen at onboarding | ✔ Line derived from the S3-filtered rate on the profile, clamped at the S2-validated goal weight. Ahead is stated and never celebrated, with a test that says so by name |
| The Run, as a screen | ✔ Headline, chart, range selector, legend, pace panel, reading list with removal, Apple Health section. ✗ never rendered, at any type size |

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

**What the first Mac session has to check, in order:** that it compiles at all (`Charts`
and `HealthKit` are both new imports); that the HealthKit entitlement and the two usage
strings are picked up, because an app that asks for authorization without them crashes
rather than fails; that The Run renders at `.xSmall` and `.accessibility5`, which is the
capture debt P1-A opened and P1-H still carries; and that a real weigh-in lands, survives
a rebuild, and appears on the chart. **Day 1 of the clock is that last one, not this
commit.**

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
> Currently working on: **[ticket]**. Everything below is verified on a real device
> against the live project as of 9 September — not written-but-unbuilt. Where something
> is written and not yet run, it says so.
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
> **P1-G is written and not yet compiled (9 Sep).** All four stories: weight entry from
> the keyboard and from Apple Health, the 7-day EWMA in Swift Charts, the zero / one /
> handful / full-week states, and the pace against the S3-filtered rate on the profile.
> The Run is a real screen rather than a holding note, `Ninety/Health/` is where the one
> `import HealthKit` lives, and ADR 0020 settles what the average is an average of — the
> series runs on calendar days, not on readings, so the chart measures the body rather
> than the weighing habit. **The next session is a Mac**: `Charts` and `HealthKit` are
> both new imports, the HealthKit entitlement and its two usage strings have never been
> exercised, and nothing here has rendered at any type size. **Day 1 of the clock is a
> real weigh-in on a real phone, not this commit.**
>
> **One gap named rather than buried, from P1-G.** The pace verdict does not say how thin
> its evidence is. Two readings a fortnight apart put the trend almost exactly on the pace
> line whatever the numbers are, so somebody who weighs twice a month reads "tracking
> inside your pace" more or less regardless. `TrendReadiness` already distinguishes the
> four cases; the pace panel does not read it. The fix is a designed state, not a
> condition, so it was left for the session that has the screen in front of it.
>
> **Three things P1-F left open, none of them blocking:** nothing has been logged with
> the radio off (P1-I's airplane-mode day, and the exit criterion stays open for it); the
> photo latency has not been read out of `Log.data` yet; and Sub On and Under Review have
> not been captured at `.xSmall` or `.accessibility5`.
>
> **One product question parked for P1-H:** whether Ninety grows real meal slots
> (breakfast / lunch / dinner) or keeps First Half / Second Half. The Today list
> currently groups by half, which costs no column — the half is a pure function of
> `logged_at`. Real slots mean a migration and a Postgres enum, so it is a decision to
> make with the dashboard in front of you rather than a patch.
>
> Requirements: offline-first (the UI never waits on network), RLS on every table, photo
> estimates always show ranges + confidence and require user confirmation. Ranges render
> as a figure plus a tolerance, never two numbers joined by a dash. The portion drives
> the calories, never the reverse. The safety rules in `docs/safety/` are Phase 1
> requirements, not Phase 3 polish. Design tokens are generated — edit
> `ninety.tokens.json`, never the Swift.

The board is the source of truth for *what is next*; this file is the source of truth for
*what closes the phase*.
