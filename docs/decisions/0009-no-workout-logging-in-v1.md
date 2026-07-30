# ADR 0009 — No workout logging in v1; read workouts passively from HealthKit

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §03, §1.4

## Context

Hevy-style set/rep/weight tracking is an entire application in its own right. It needs
an exercise library, per-set entry UI, rest timers, routine templates, plate maths,
progress-per-lift charts, and a history view. Hevy is a company, not a feature.

Building it would roughly double the build and halve the focus.

But the ranking engine genuinely wants training signal. Activity is part of
consistency, and dropping it entirely would make the composite weaker.

## Decision

No workout logging UI in v1.

**Read workouts passively from HealthKit** — `HKWorkoutType`, plus `stepCount`,
`activeEnergyBurned` and `appleExerciseTime`.

## Trade-off accepted

The app is a **nutrition-and-consistency product at launch**, not a full fitness
tracker. Someone who lifts but does not track food gets less out of it.

Workout data is also less precise passively: a HealthKit workout gives duration, type
and energy, not what was actually done. The engine can know "trained four times this
week", not "squatted 100 kg".

For a consistency metric, that is sufficient. Consistency does not need to know the
weight on the bar.

## The part that is genuinely elegant

Passive reads give the signal **without the UI** — which is exactly how the v1 scope
stays sane. And per §2.3, passive data from the motion coprocessor is *far harder to
fabricate than a number typed into a text field*, so it should be weighted accordingly
in the composite.

So the cheap option is also the more cheat-resistant option. Building a workout logger
would have meant adding a large surface of user-typed, trivially-forgeable numbers to a
competitive scoring system. Not building it avoids that entirely.

## Reversal trigger

Phase 3 or 5 data showing workout logging is what users actually ask for, unprompted,
in the feedback channel — and specifically that its absence is a stated reason someone
stopped using the app (the churn-point metric will show this).

§09 already parks it in Phase 5, gated on exactly this: *"Workout logging, if and only
if the data says users want it."*
