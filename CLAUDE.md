# Ninety — repository map

Native iOS health app that ranks on **normalised improvement and consistency**, not
absolute numbers. Swift 6.3 / SwiftUI / iOS 18+ / Supabase.

**Phase 0 closed 31 Aug 2026** — every exit criterion met, HealthKit proven on a real
device. **Phase 1 (single-player core) is live** and is the first phase that builds.
P1-A landed the foundations: `Ninety/` (the app), `Packages/RankingEngine` (the Phase 2
boundary, scaffolded so the purity lint has something to police), and ADR 0015 settling
the type decision that blocked every view ticket. P1-D added `Ninety/Safety/`, which is
where §10's S1–S7 live as types rather than as review notes — if you are touching a
calorie target, a goal weight, a rate of loss or an age check, that is the directory.

**Read this file first and then only what you need.** Everything below is reference
material — the whole repo is ~4,400 lines of prose and reading it end to end is a waste.

---

## Where to look, by question

| If the question is… | Read only |
|---|---|
| What is this project, what's the pitch | `README.md` |
| The brief itself (§ references resolve here) | `docs/brief/` — but read the ADR or safety rule first; only §2.2's maths and §2.3's anti-gaming live nowhere else |
| What Phase 0 proved, and the measured numbers | `docs/phase-0/07-spike-findings.md` |
| What Phase 1 has to do, and what closes it | `docs/phase-1/README.md` — the live tracker |
| What Phase 0 closed on, and the product state | `docs/phase-0/README.md` (closed) + `PRODUCT.md` |
| Why was X decided that way | `docs/decisions/README.md` index → the one ADR |
| Is a number safe, what's banned in copy | `docs/safety/safety-requirements.md` |
| Where does a key live, what if one leaks | `docs/security/secrets.md` |
| What a screen should look like | `design/redesign/README.md` → the six PNGs in `screens/` |
| How the world is built in SwiftUI | `DESIGN.md` — type, colour, structure, and the recorded deviations |
| Why the app looks like a football broadcast | `design/redesign/README.md`, and `PRODUCT.md` §Brand Commitments |
| Component/copy rules behind a screen | `design/spec/` + `design/preview/design-system.html` |
| What a colour or spacing value is | `design/tokens/ninety.tokens.json` — **generated, never hand-edit the Swift/CSS** |
| How the vision harness works | `spikes/vision-accuracy/README.md` |
| HealthKit patterns for Phase 1 | `spikes/healthkit/HealthSpike.swift` (the notes at the bottom) |
| Measured numbers so far | `docs/phase-0/07-spike-findings.md` |
| Commit/PR conventions | `CONTRIBUTING.md` |

**Do not read all the ADRs.** The index in `docs/decisions/README.md` is one line each;
open only the one that matters.

---

## Directory map

```
docs/
  phase-1/     the LIVE tracker. Exit criteria, the running order, the 21-day clock.
               jira-import.csv seeded the board — 11 epics, 60 issues
  phase-0/     closed tracker. accounts.md is a runbook, not reading
  decisions/   18 ADRs. Index first, then one file. Never renumber
  safety/      §10 as numbered rules S1-S7 with test names. Load-bearing for Phase 1
  security/    secrets policy. The anon key is public; RLS is the security boundary

design/
  tokens/      ninety.tokens.json is the SINGLE SOURCE OF TRUTH for every colour
  generated/   emitted by generate.py. Never edit by hand — CI fails on drift
  preview/     design-system.html — the visual reference
  spec/        principles, component specs, copy deck (17 phrases banned at lint-error)
  redesign/    the MATCHDAY world: six screens as .dc.html + rendered PNGs

supabase/
  migrations/  applied in filename order by `supabase db push`. RLS is IN migration 001
  functions/   estimate-meal — the photo route's server half. The model API key lives
               here and nowhere else (§04). `deno test supabase/functions` in CI
  tests/       the two-account RLS proof. scripts/verify-rls.sh boots its own Postgres

spikes/        THROWAWAY de-risking code, not app code. Different quality bar
  vision-accuracy/   photo->calorie harness. Runs, scores, reports. Python
  healthkit/         Spike A. Blocked on Apple Developer enrolment

scripts/       verify-toolchain.sh (the Mac) · verify-accounts.sh (the .env)
.githooks/     secret + health-data tripwires, conventional commits. Opt in with:
               git config core.hooksPath .githooks
```

```
Ninety/          the app. App/ · DesignSystem/ · Features/ · Resources/Fonts/
                 A synchronized folder in Xcode — new files need no .pbxproj edit
NinetyTests/     unit tests (Swift Testing)
Packages/        RankingEngine. Pure, no dependencies, three lint rules guard it
Config/          xcconfig + Info.plist. Local.xcconfig (gitignored) holds your team id
```

CI decides on Ubuntu whether a change touches Swift before starting a macOS runner —
docs and design commits never spend the 200-minute budget.

---

## Things that will bite you

- **Colours are generated.** Edit `ninety.tokens.json`, run
  `python3 design/tokens/generate.py`, commit both. `--check` runs in CI and fails on
  drift. The generator also validates WCAG AA and will refuse a failing pair.
- **`.env` is not merged, it is shadowed.** The loader walks up and takes the *nearest*
  file, then stops. Keep exactly one, at the repo root.
- **The thesis wording is narrow on purpose** (ADR 0013). Not "nobody rewards
  consistency" — Strava does. "Consistency is a side badge everywhere; here it is the
  rank, and it is normalised." Don't let it drift back.
- **Safety numbers are unreviewed.** Fine for one user, gated before Phase 3.
  `docs/safety/clinician-review-pack.md` is the document to send.
- **Never invent a cost figure.** The harness refuses to run an unpriced model rather
  than reporting $0.00. Don't reintroduce a zero default.
- **Photos and ground truth are gitignored.** Article 9 health data. Reports are
  committed; the data is not.
- **The confirmed values from the app are not weighed ground truth** (ADR 0019). They
  measure how far a human moved the model, which is real and useful; they are not the
  accuracy baseline, and `spikes/vision-accuracy`'s own rules say why. The 20 weighed
  meals are still outstanding.
- **The portion drives the numbers, not the other way round.** A catalogue row
  knows kcal per 100 g and nothing else; `PortionBasis` scales it. The screen
  that did not do this logged 200 g of food at 100 g of energy for a day.
- **A range is a figure and a tolerance, never a dash** — `1,850 ±100`, not
  `1,750–1,950`. `DESIGN.md` § Numbers, and `SafetyCopyTests` checks it.

---

## Commands

```bash
python3 design/tokens/generate.py --check      # CI runs this
python3 -m pytest spikes/vision-accuracy/tests -q
deno test supabase/functions                   # the Edge Function contract
scripts/verify-rls.sh                          # boots a throwaway Postgres, 33 assertions
scripts/verify-toolchain.sh                    # macOS only
scripts/verify-accounts.sh                     # reads .env, never prints a value
```

---

## Conventions

- **Conventional commits**, enforced by the commit-msg hook: `type(scope): subject`.
- **Phases end on a testable condition, not a date.** If a criterion is closed on
  different evidence than originally written, say so in the tracker rather than
  quietly ticking it.
- **Reversing an ADR** needs an appended `## Reversed` section stating what new
  information changed it. "I changed my mind" is not new information.
- **`TO BE MEASURED`** marks a real outstanding placeholder. CI prints them; don't
  invent values to clear one.
- **The 21-day clock is calendar, not work.** Phase 1 cannot close fewer than 21 days
  after the app first becomes daily-usable, so the running order exists to start that
  clock early — see `docs/phase-1/README.md`. Once it runs, anything that breaks a
  day's logging is fix-now.
