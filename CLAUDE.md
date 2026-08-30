# Notch — repository map

Native iOS health app that ranks on **normalised improvement and consistency**, not
absolute numbers. Swift 6.3 / SwiftUI / iOS 18+ / Supabase. **Phase 0** (de-risking);
no app code exists yet, deliberately.

**Read this file first and then only what you need.** Everything below is reference
material — the whole repo is ~4,400 lines of prose and reading it end to end is a waste.

---

## Where to look, by question

| If the question is… | Read only |
|---|---|
| What is this project, what's the pitch | `README.md` |
| What's left in Phase 0, what's blocked | `docs/phase-0/README.md` |
| Why was X decided that way | `docs/decisions/README.md` index → the one ADR |
| Is a number safe, what's banned in copy | `docs/safety/safety-requirements.md` |
| Where does a key live, what if one leaks | `docs/security/secrets.md` |
| What a screen should look like | `docs/design/` + `design/preview/design-system.html` |
| What a colour or spacing value is | `design/tokens/notch.tokens.json` — **generated, never hand-edit the Swift/CSS** |
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
  phase-0/     the live tracker + exit criteria. accounts.md is a runbook, not reading
  decisions/   13 ADRs. Index first, then one file. Never renumber
  safety/      §10 as numbered rules S1-S7 with test names. Load-bearing for Phase 1
  security/    secrets policy. The anon key is public; RLS is the security boundary
  design/      principles, component specs, copy deck (17 phrases banned at lint-error)

design/
  tokens/      notch.tokens.json is the SINGLE SOURCE OF TRUTH for every colour
  generated/   emitted by generate.py. Never edit by hand — CI fails on drift
  preview/     design-system.html (the visual reference) + a paste-into-chat brief

spikes/        THROWAWAY de-risking code, not app code. Different quality bar
  vision-accuracy/   photo->calorie harness. Runs, scores, reports. Python
  healthkit/         Spike A. Blocked on Apple Developer enrolment

scripts/       verify-toolchain.sh (the Mac) · verify-accounts.sh (the .env)
.githooks/     secret + health-data tripwires, conventional commits. Opt in with:
               git config core.hooksPath .githooks
```

No `Notch/` or `Packages/` yet. CI probes for them and skips the expensive macOS job
until they exist.

---

## Things that will bite you

- **Colours are generated.** Edit `notch.tokens.json`, run
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

---

## Commands

```bash
python3 design/tokens/generate.py --check      # CI runs this
python3 -m pytest spikes/vision-accuracy/tests -q
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
