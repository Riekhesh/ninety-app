# ADR 0007 — Fixed tier thresholds, not percentiles

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §2.2

## Context

Two ways to map a composite score onto Bronze → Diamond:

- **Percentile** — you are Gold if you are in the top 30% of users this week.
- **Fixed threshold** — you are Gold if your composite score is ≥ 0.65.

Percentile ranking requires a user population. Through Phase 3 that population is
between one and eleven people, which makes percentiles meaningless.

## Decision

Fixed thresholds in v1. Recalculated weekly. Revisited once Phase 3 produces real
distribution data.

## Trade-off accepted

Thresholds need manual re-tuning once real distribution data arrives (an explicit
Phase 3 exit criterion). The initial numbers are a guess informed by the developer's
own data, and they will be wrong.

## The reason this is right beyond the cold-start problem

Percentiles make a user's rank move **for reasons they did not cause.** You can have
your best week ever and drop a tier because other people also had a good week.

That is arbitrary, it feels unfair, and — more importantly — it directly contradicts
the thesis. The whole product claim is *"this compares you to who you were last
month."* A rank that moves because of strangers is a rank that compares you to
strangers. The cold-start problem makes fixed thresholds necessary; the thesis makes
them correct.

Fixed thresholds also mean a tier is a **statement about you**, so "Gold" carries the
same meaning in week 3 and week 30. That is what makes the weekly rank-up a
meaningful retention moment rather than noise.

## Reversal trigger

Consider percentile *bands within a tier* (never percentile tiers themselves) if user
count exceeds ~1,000 and the distribution turns out badly clustered — for example if
80% of users sit in one tier, which makes the ladder uninformative.

Even then, the thesis constraint holds: a user's own tier must never move because of
another user's week.
