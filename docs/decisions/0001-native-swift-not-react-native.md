# ADR 0001 — Build native Swift / SwiftUI, not React Native

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02

## Context

The app needs deep HealthKit access (`bodyMass`, `stepCount`, `activeEnergyBurned`,
`appleExerciseTime`, workouts), background delivery of health samples, and
`VisionKit`'s `DataScannerViewController` for barcodes. Every person in the immediate
testing circle for Phase 3 is on iOS.

Cross-platform frameworks reach HealthKit through bridges that lag the native API and
tend to expose a lowest-common-denominator subset. Background delivery and anchored
queries in particular are where those bridges are thinnest.

## Decision

Build natively in Swift 6.3 / SwiftUI. No cross-platform layer.

## Trade-off accepted

**Android is deferred, not free.** If the app ever needs Android, the UI is a full
rebuild — not a port.

Partial mitigation: Swift 6.3 shipped the first official Swift SDK for Android, so
pure-logic packages can be shared later. This is a concrete reason the
`RankingEngine` package must stay free of UI and platform imports (ADR 0006) — it is
the one component that could cross over intact, and it is also the component whose
logic is most expensive to reimplement correctly.

## Reversal trigger

Not reversible within v1 — by Phase 1 the sunk cost is decisive.

Would be worth revisiting *for a v2* if Phase 3 retention data shows the product
works and more than roughly a third of people asking for access are on Android. That
is a rewrite decision made from evidence, not a framework decision made in advance.
