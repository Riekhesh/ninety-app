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
| **P1-A** Foundations & app skeleton | **Built 2 Sep, not yet compiled.** Xcode project, `Packages/`, tokens wired in, macOS CI gated, type decision settled. Closes when a Mac builds it | Highest |
| **P1-B** Data layer, schema & RLS | **4 of 5 done, 2 Sep.** Migrations applied to the live project, RLS proven with two accounts, SwiftData models, repositories. Food mirror deferred | Highest |
| **P1-C** Authentication | **Both stories done, 7 Sep.** Sign in with Apple through Supabase's id-token exchange, and Article 9 consent recorded separately from ToS. Not compiled | High |
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
4. **Onboarding, with the safety gates wired in as it is built.** S1–S4 are onboarding
   logic, not a review pass over finished screens. Each arrives with its test names
   already written in `docs/safety/`. It also carries the first Settings surface, which
   is where S6's opt-out, S7's signposting and P1-C's consent withdrawal all live.
5. **Kick off.** The minimum set above. Record day 1.
6. **Everything else, underneath a running clock.** Barcode, photo, HealthKit, sync,
   Matchday polish.

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

**Not verified here, and honestly outstanding.** This work was done in a Linux
container: no Xcode, no Swift toolchain, no simulator. Nothing has been compiled. The
first Mac session should run `scripts/verify-guardrails.sh`, open the project, build to
the device, and record the result on the P1-A ticket. See
[the handover](#first-mac-session) below.

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
| Mirror Open Food Facts + USDA | **Deferred** — see below |

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

**Still not compiled.** Same caveat as P1-A: the Swift in this epic was written
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

**The gap, named rather than buried.** Consent can be withdrawn on the consent
screen, and `ConsentRecorder` supports withdrawing either at any time — but once
both are given the shell moves on, and Ninety has no Settings screen to withdraw
from yet. The copy therefore describes what withdrawal *does* and does not
promise where to find it. **P1-D closes this**: the screen carrying S6's opt-out
switch and S7's signposting carries this too.

**Not verified here, and honestly outstanding.** Same caveat as P1-A and P1-B,
plus one more that is new. This was written in a Linux container with no Xcode,
so nothing is compiled — and P1-C is the first epic to take a **remote** Swift
package (`supabase-swift`, pinned to 2.x). It has never been resolved, so
`Package.resolved` does not exist and the SDK call sites have never seen a
compiler. If any of them have moved, they are all in
`Ninety/Auth/SupabaseAuthService.swift` and nowhere else — which is the whole
reason `AuthServiceProtocol` exists.

---

## Out of scope, and where it went

| | |
|---|---|
| Open Food Facts + USDA mirror | Moved out of P1-B to land with P1-F's search route. The `foods` table and its index ship now; the import is a data job |
| Ranking maths, tiers, anti-gaming | Phase 2. `Packages/RankingEngine` is scaffolded now only so the lint purity rules have a boundary to police |
| The scoring half of S3 | Phase 2 — progress score peaking at target rate |
| Privacy policy, export, deletion, S7 triggers | Phase 3, before the first external tester |
| Friends and leaderboards | Phase 4 — but their two tables ship empty in migration 001, because retrofitting relationships hurts |
| PostHog | Phase 3 |
| Workout logging or UI | ADR 0009. Workouts are read passively and never surfaced |

---

## First Mac session

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

---

## Handoff prompt for a fresh session

> I'm on Phase 1 (Single-Player Core) of Ninety. Building food logging, weight tracking,
> HealthKit sync, and the Matchday dashboard. Architecture: SwiftUI + `@Observable`
> ViewModels + protocol-based repositories, SwiftData local store with an outbox pattern
> syncing to Supabase.
>
> Currently working on: **[ticket]**. P1-A is closed: the project builds, the type
> decision is ADR 0015 (Dynamic Type, two bundled faces), the shell is three tabs with
> Sub On as a sheet, and `DESIGN.md` is the authority on how the world is built.
> P1-C is closed: Sign in with Apple is the only identity route (ADR 0016), and the app
> will not start until Article 9 health consent is recorded separately from terms
> acceptance (ADR 0017). Every repository is built from the signed-in user's id.
>
> Requirements: offline-first (the UI never waits on network), RLS on every table, photo
> estimates always show ranges + confidence and require user confirmation. The safety
> rules in `docs/safety/` are Phase 1 requirements, not Phase 3 polish. Design tokens are
> generated — edit `ninety.tokens.json`, never the Swift.

The board is the source of truth for *what is next*; this file is the source of truth for
*what closes the phase*.
