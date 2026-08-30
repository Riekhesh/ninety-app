# ADR 0008 — Weight consistency above progress (0.50 / 0.25 / 0.25)

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §2.2

## Context

```
S = wc·C + wa·A + wp·P

C = consistency   A = adherence   P = normalised progress
wc = 0.50         wa = 0.25       wp = 0.25
```

Three candidate weightings, roughly:

- **Progress-heavy** — rewards results. Most motivating in week one, and the most
  gameable and least fair across starting points.
- **Balanced thirds** — defensible, and says nothing in particular.
- **Consistency-heavy** — rewards showing up.

## Decision

`wc = 0.50`, `wa = 0.25`, `wp = 0.25`. Consistency carries half the composite.

## Reasoning

**It is the strongest real-world predictor of outcomes.** Adherence over time beats
intensity in essentially every weight-management context.

**It is the hardest metric to fake.** You cannot sandbag showing up for eight straight
weeks. Progress can be manipulated by lying about a starting weight; adherence can be
manipulated by mis-logging; consistency requires actually opening the app and logging
plausible food on 7 days out of 7. Weighting the least-forgeable signal highest is an
anti-gaming decision as much as a product one.

**It serves the thesis.** Consistency is the metric a complete beginner can win at
today, with no fitness, no equipment and no head start. That is the entire point.

## Trade-off accepted

Users chasing fast visible results may find early ranks feel unresponsive. Someone who
loses 2 kg in a fortnight but logged 4 days a week will rank below someone who lost
0.4 kg and logged 14 days out of 14, and that will feel wrong to them.

**Mitigate through copy, not by reweighting.** The rank screen must explain what moved
and what would move it next, so an unresponsive-feeling rank becomes legible rather
than arbitrary. See `design/spec/04-copy-deck.md`.

The temptation to reweight after the first person complains is exactly what §02 is
written to prevent.

## Reversal trigger

Phase 3 retention data showing that users who rank low *specifically because of the
consistency weighting* churn measurably faster than the cohort baseline.

This requires actually segmenting on it — "someone said it felt unfair" is not the
trigger, and neither is the developer's own impatience in week five. If it is
reversed, record the segment sizes and the retention delta here.
