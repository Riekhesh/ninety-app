# ADR 0002 — Target iOS 18.0, build against the iOS 26 SDK

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §0.1

## Context

Two separate numbers get confused here, so state both:

- **Deployment target** — the oldest iOS a device can run and still install the app.
- **SDK / toolchain** — what the app is compiled *against*.

Since 28 April 2026 the App Store requires builds made with Xcode 26+ against the
iOS 26 SDK. That is a submission floor and not negotiable.

iOS 18 as a deployment target unlocks the Observation framework, SwiftData and Swift
Charts — all three are load-bearing in the architecture — while keeping broad device
coverage.

## Decision

Deployment target **iOS 18.0**. Build with **Xcode 26.6 (Swift 6.3)** against the
**iOS 26 SDK**.

Develop on stable Xcode. Do not develop on the Xcode 27 beta for a project intended
to ship.

## Trade-off accepted

Excludes a small tail of older devices. Irrelevant at this stage — the Phase 3 tester
group is a handful of friends whose devices are known.

Also accepts that any API newer than iOS 18 needs an `if #available` check, which
adds a small amount of noise. Worth it for the coverage.

## Reversal trigger

Raise the target to iOS 26 only if a specific API the app genuinely needs is 26-only
*and* the workaround is materially worse. Note the API and the workaround here when
that happens.

Apple raising the submission floor again (which happens roughly annually each spring)
changes the SDK line, not the deployment target line. That is a toolchain bump, not a
reversal of this decision.
