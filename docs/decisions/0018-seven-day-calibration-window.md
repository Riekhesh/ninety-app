# 0018 · The calibration window is seven days, not fourteen

**Status:** Locked · **Phase:** 1 · **Date:** 8 September 2026

## Context

§2.3 sets a **14-day calibration window** as the first of the anti-gaming rules: the
app watches a new user's first fortnight, establishes a baseline with outlier
rejection, and shows no tier until it closes. Every surface built so far repeats the
number — `PRODUCT.md`, `design/spec/04-copy-deck.md` ("The first two weeks are
calibration"), `design/spec/02-components.md` on the stat card and the tier badge, the
`profiles.calibration_completed_at` comment, and `Profile.isCalibrated`.

The window exists for two separate reasons that are easy to conflate:

1. **A baseline needs data.** Ranking on normalised improvement means improvement
   against *your own* starting point, and a starting point computed from two days is
   noise wearing a number.
2. **Sandbagging is an attack.** §2.3 names it explicitly — deliberately under-logging
   during calibration to make every subsequent week look like progress. A longer window
   is more expensive to sandbag convincingly.

Neither reason fixes the number at fourteen. Fourteen is what the brief guessed.

The thing that has changed since the brief is that the number now has a cost we can
state. Ninety's differentiator is the rank; it is the entire reason the app is not
another calorie tracker. A 14-day window means **a new user does not see the one thing
the product is for until their third week** — and §1.5 records that the first fortnight
is exactly when weight-tracking apps get abandoned. The app spends its whole retention
budget asking someone to keep logging on faith.

That interacts badly with the Phase 1 dogfood clock too. Twenty-one consecutive days is
the exit criterion; with a 14-day window the first real tier lands with a week of the
phase left, which is one rank reveal to evaluate the entire ranking design against.

## Decision

**The calibration window is seven days.** A user's first tier is assigned at the end of
their first week.

`CALIBRATING · N days to go` counts down from 7. `profiles.calibration_completed_at`
keeps its meaning exactly — null while the window is open, stamped when it closes — and
is unchanged as a column.

## The trade-off, knowingly accepted

**A 7-day baseline is a worse baseline, and this ADR does not pretend otherwise.**

- **Outlier rejection gets thin.** §2.3's "drop the extremes" over 14 points leaves 12.
  Over 7 it leaves 5. Trimming both extremes from a week discards 29% of the sample.
- **One unusual week is now the whole baseline.** A user who calibrates through a stag
  do or a stomach bug has no other week to dilute it. Over a fortnight, one bad week is
  half the picture; over a week it is all of it.
- **Sandbagging gets cheaper per day.** Seven days of deliberate under-logging is an
  easier lie to sustain than fourteen. It also *buys* less — the baseline it poisons is
  the one every later week is measured against, and §2.3's other three defences (the
  48-hour edit lock, the delta cap, the z-score plausibility flag) are unchanged and do
  not depend on the window's length.

**Two constraints this places on Phase 2**, recorded here so the maths is not designed
in ignorance of them:

1. **The baseline statistic must be robust at n=7**, which a trimmed mean over five
   surviving points is not really. A median, or a weighted mean that de-weights rather
   than discards extremes, is the shape to reach for.
2. **The first tier must be reversible without reading as a punishment.** A rank
   assigned on a thinner baseline will move more in week two, and the copy deck's reset
   framing (§6, "Reset to Silver. Gold is four consistent days away.") is what makes
   that survivable. S5 already forbids the alternative.

## What was considered and rejected

**Ten days.** Splits the difference and inherits both problems: still not a week the
user recognises, still thin for trimming. A number chosen to avoid choosing.

**Seven days, but no tier until fourteen.** Keeps the statistical safety and gives the
user a countdown that ends in nothing. Worse than either honest option.

**A window that closes on seven *logged* days rather than seven calendar days.** Sound
on the statistics and unacceptable on the incentive: it makes the countdown something a
user can accelerate by logging, which is a streak mechanic wearing a baseline's clothes,
and §10 is explicit about what streak pressure does. Calendar days are not gameable
because they are not earned.

## Reversal trigger

Go back to fourteen — or to a window that adapts to observed variance — if **either**
holds:

- Across the Phase 1 dogfood set (21 days of real logs, the test set for the whole
  engine), a baseline computed from days 1–7 and one computed from days 1–14 assign
  **different tiers for week 3**. That is the direct measurement of whether the shorter
  window is buying speed at the cost of correctness, and Phase 2 has the data to run it.
- Phase 3 testers show week-1 tiers that do not hold in week 2 for more than a small
  minority — a rank that immediately resets is worse for trust than a rank that arrives
  a week later.

"It felt slow" is what motivated this ADR and it is a legitimate product observation;
it is not the evidence that would reverse it.

## Consequences

| Where | Change |
|---|---|
| `PRODUCT.md` | First 7 days = calibration |
| `design/spec/04-copy-deck.md` | "The first week is calibration"; body rewritten to 7 |
| `design/spec/02-components.md` | Stat card and tier badge calibrating states |
| `supabase/migrations/…_calibration_window.sql` | Column comment corrected in a new migration; migration 001 is applied and stays as written |
| `Ninety/Safety/CalibrationWindow.swift` | `CalibrationWindow.days = 7`, the one place the number exists in Swift |
| `docs/phase-1/jira-import.csv` | P1-D's calibration story |

§2.3 in `docs/brief/` is left as written. The brief is the record of what was decided in
August, not a live document, and this file is how it is superseded — the decision index
is where a reader is sent to find out whether a brief number still stands.
