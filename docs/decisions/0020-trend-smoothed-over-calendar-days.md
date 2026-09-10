# 0020 · The weight trend is smoothed over calendar days, not over readings

**Status:** Locked · **Phase:** 1 · **Date:** 9 September 2026

## Context

§1.5 asks for a **7-day exponentially weighted moving average** of body weight and is
unusually forceful about why: daily weight is mostly water, glycogen and gut content,
and showing it raw *"produces a jagged line that makes a genuinely successful week look
like failure … one of the main reasons people abandon weight-loss apps in the first
fortnight."* The brief specifies the statistic and Swift Charts, and stops there.

What it does not specify is **what the average is an average of**, and there are two
readings of "7-day EWMA" that produce different lines from identical data:

1. **Over the readings.** Take the array of weigh-ins, apply `t ← t + α(r − t)` to each
   in turn. One line of code, and it is what almost every tutorial implementation does.
2. **Over the calendar.** Collapse the weigh-ins to one value per day, then step one day
   at a time from the first to the last, updating on days that have a reading and
   carrying the average forward on days that do not.

They agree exactly when the user weighs themselves every single day, which is why the
difference is easy to miss: the happy path is identical, and the divergence only shows
up in the data of somebody who missed a day — which, over 21 days, is everybody.

Under the first reading, α is applied per *reading* rather than per *day*, so the
smoothing constant silently becomes a function of how often the user remembers. Somebody
who weighs twice a week gets a trend that reacts about 3.5× too fast; somebody who
weighs twice a day gets one that reacts half as fast as it should. Worse, the same
person's chart **changes shape depending on their weighing habit rather than their
weight** — a fortnight of daily readings followed by a fortnight of Mondays draws a line
that steepens for reasons that have nothing to do with their body.

There is also a third option worth naming, because it is the more sophisticated one:
**time-decayed α**, where a gap of *n* days uses `α' = 1 − (1 − α)^n`. It is arguably
the most correct treatment of the smoothing constant, and it is rejected below.

## Decision

**The series runs on calendar days.** `WeightTrend` collapses weigh-ins to one value per
day in the user's own calendar — the **mean** of that day's readings — then walks the
span one day at a time. A day with a reading updates the average; a day without one
carries it forward unchanged and contributes no new information.

Three consequences follow and are part of the decision:

- **The smoothed series is defined on every day of the span**, so the chart has a
  continuous line and the raw dots sit only on the days that produced one. A dot on a
  carried day would be a measurement the app invented.
- **The series ends at the last reading, not at today.** Carrying a flat line forward to
  the present would draw a weight for days nobody measured, which `DESIGN.md` § Numbers
  rules out in as many words.
- **The four-week comparison is trend against trend**, never reading against reading.
  Comparing today's number with the one from four weeks ago compares two days of water
  retention and calls the difference progress — the same mistake as showing the raw
  line, made once instead of continuously.

The calendar is a parameter throughout, never `Calendar.current` read inside the type.

## The trade-off, knowingly accepted

**A carried day is a claim that nothing happened, and that is not quite true.** Someone
who does not weigh in for a fortnight has almost certainly changed weight during it, and
this implementation draws a flat line across the gap and then a single α-step at the
far end. The line understates what happened in the middle.

That is accepted because the alternative is worse in a specific way: the app would be
drawing a slope through days it has no data for. A flat carry is visibly "nothing was
measured here"; an interpolated slope is a guess rendered identically to a measurement.

**A second consequence, which surfaced writing the tests.** Two readings a fortnight
apart produce a trend that sits almost exactly on the pace line however different the
two numbers are, because one α-step moves it by a quarter of the gap. So a user who
weighs twice a month will be told "tracking inside your pace" more or less regardless.
This is arithmetically correct — somebody with two readings does not have a trend that
can meaningfully be ahead or behind anything — and it is currently **not surfaced**: the
screen says the pace verdict without saying how thin the evidence is. `TrendReadiness`
distinguishes zero, one, a handful and a full week, and the pace panel does not read it.
That is a real gap and it is named in the tracker rather than left to be discovered.

## What was considered and rejected

**Smoothing over the readings array.** Rejected above: it makes α a function of weighing
frequency, which means the chart measures the habit rather than the body.

**Time-decayed α — `α' = 1 − (1 − α)^n` across an n-day gap.** The most defensible of
the three on pure signal-processing grounds, and rejected on two counts. It produces the
*same* line as the calendar walk everywhere it matters — the difference is confined to
what value a gap day is assigned, and gap days are not drawn as readings either way —
while being materially harder to explain, to test and to port. And Phase 2's progress
score reads this series: the ranking engine has to be reproducible from test vectors on
a server (§4's hard gate), and a per-gap exponent is a place for the two implementations
to disagree in the sixth decimal. A day-stepped walk is the same loop in any language.

**Taking the last reading of a day rather than the mean.** Rejected: it lets the order
entries were typed in move the line. Taking the *lowest* of a day was rejected faster —
that is the app helping the user flatter themselves, which is the whole category of
thing §10 exists to prevent.

**Putting the trend in `Packages/RankingEngine` now.** Tempting, because Phase 2 will
read it. Rejected as premature: the engine's purity rules exist to keep it portable, and
nothing in Phase 1 scores anything. `WeightTrend` is already pure, takes its calendar as
a parameter, and reads through `WeighIn` rather than the SwiftData row — so moving it is
a file move, not a rewrite, on the day Phase 2 actually needs it.

## Reversal trigger

Move to time-decayed α if **either** holds:

- The Phase 1 dogfood set (21 days of real logs) contains a gap long enough that the
  carried line and a time-decayed one give **different pace verdicts** on the same day.
  That is the direct measurement, and Phase 2 has the data to run it.
- Phase 2's progress score turns out to be sensitive to the treatment of gap days — that
  is, `actual_change / expected_change` moves by enough to cross a tier boundary
  depending on which is used. The engine's own test vectors will show this.

"It is more mathematically elegant" is what motivated writing this section and is not
evidence that would reverse the decision.

## Consequences

| Where | Change |
|---|---|
| `Ninety/Features/TheRun/WeightTrend.swift` | The walk, the collapse, and `TrendReadiness` |
| `Ninety/Features/TheRun/Pace.swift` | Anchors on the first *trend* value, not the first reading |
| `NinetyTests/WeightTrendTests.swift` | The gap tests are this ADR as assertions |
| `docs/phase-1/README.md` | P1-G's record, and the pace-thinness gap named above |
