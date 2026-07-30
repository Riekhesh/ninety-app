# Working on Notch

Solo project. These conventions exist for one reason: **the git history is a portfolio
artifact that people genuinely do look at** (§0.6). A clean history costs nothing to
maintain and is impossible to retrofit.

---

## Branches

`main` is always buildable. Everything else is a short-lived branch off `main`.

```
<type>/<short-kebab-description>

feat/barcode-scanner
fix/healthkit-anchor-not-persisted
spike/vision-accuracy-baseline
docs/phase-0-design-system
chore/bump-swiftlint
```

Merge with a squash when the branch is exploratory and messy; merge with a
merge commit when the individual commits tell a story worth keeping (the
ranking engine work in Phase 2 will be the latter — each anti-gaming rule
and its test should stay a discrete commit).

Delete the branch after merge.

---

## Commits — Conventional Commits

```
<type>(<scope>): <subject>

[optional body — the *why*, not the *what*. The diff already says what.]

[optional footer — BREAKING CHANGE:, Refs:, Closes:]
```

Subject line: imperative mood, lower case, no trailing full stop, ≤ 72 chars.
"add barcode lookup", not "Added barcode lookup." or "adds barcode lookup".

### Types

| Type | Use for |
|---|---|
| `feat` | A user-visible capability |
| `fix` | A bug fix |
| `perf` | A change that makes something measurably faster |
| `refactor` | Behaviour-preserving restructuring |
| `test` | Adding or correcting tests |
| `docs` | Documentation, ADRs, design specs, the brief |
| `design` | Design tokens, component specs, wireframes *(non-standard; this project has a real design surface and it deserves its own type)* |
| `build` | Xcode project settings, SPM dependencies, entitlements |
| `ci` | GitHub Actions |
| `chore` | Housekeeping with no product effect |
| `spike` | Throwaway de-risking code *(non-standard; §0.7 spikes are explicitly not production code and should be legible as such in the log)* |
| `revert` | Reverting a previous commit |

### Scopes

Match the architecture, so `git log --oneline --grep "(rank)"` is useful:

`auth` · `onboarding` · `log` · `search` · `barcode` · `photo` · `weight` ·
`health` · `dashboard` · `rank` · `sync` · `db` · `design` · `safety` ·
`analytics` · `deps` · `repo`

### Examples

```
feat(barcode): add DataScannerViewController lookup path

Barcode is the fastest logging path for packaged food and close to free to
implement (§1.3), so it ships before photo logging despite being less
interesting. Falls back to manual search when Open Food Facts has no record
for the code.

feat(rank): add 14-day calibration window with outlier rejection

Primary defence against sandbagging (§2.3). Drops the highest and lowest
daily values before establishing the baseline. No progress score is computed
until the window closes.

Refs: docs/decisions/0011-calibration-window.md

test(rank): add failing test for sandbagged calibration window

Deliberately committed red. The naive implementation in the previous commit
passes a user who logs a weak first fortnight straight to Gold.

fix(health): persist HKAnchoredObjectQuery anchor across launches

Without this the app re-queried full history on every cold start — four
seconds of hang on a device with two years of step data.

design(design): add tier badge notch-count encoding

Tier is encoded in notch count as well as metal colour, so the ladder is
legible without colour vision. Silver and Platinum were otherwise too close.
```

### Referencing the brief

Cite the brief section that motivated a change (`§2.3`, `§1.3`) in commit
bodies. In six months, when you are writing the report, this is how you
reconstruct *why* — and it is how a fresh session picks up where you left off
(§10, solo bus factor).

---

## Before you commit

```bash
swiftlint                 # zero warnings on main. It was configured in Phase 0
                          # while there were none — keep it that way.
swift test                # once Packages/RankingEngine exists
scripts/check-tokens.sh   # design tokens and generated Swift agree
```

`git commit` runs these via `.githooks/pre-commit`. Enable the hooks once per
clone:

```bash
git config core.hooksPath .githooks
```

---

## Never commit

- **Secrets of any kind.** See [docs/security/secrets.md](docs/security/secrets.md).
  API keys live in Supabase Edge Function environment variables. A key in the
  app bundle is a key you have published — client binaries are extractable in
  minutes (§04).
- **Your own health data.** Meal photos, HealthKit exports, and weight logs are
  special category data under UK GDPR Article 9 (§10). `.gitignore` covers the
  known paths; think before adding new ones.
- **`xcuserdata/`.** It churns on every build.
- **Spike code promoted into the app.** Spikes are throwaway by decision
  (§0.7). If spike code turns out to be worth keeping, rewrite it deliberately
  in a `feat` commit rather than letting it drift in.
