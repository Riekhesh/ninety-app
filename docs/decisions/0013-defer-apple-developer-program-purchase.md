# ADR 0013 — Defer the Apple Developer Program purchase until a signing test says otherwise

**Status:** Locked
**Date:** 2026-08-30
**Phase:** 0
**Brief reference:** §0.1, §0.7

## Context

Phase 0's last open exit criterion is Spike A — *"your own real step and weight history
rendering on your own iPhone."* Everything else is done or deliberately descoped.

The repo has said since day one that Spike A is blocked on a $99 + VAT Apple Developer
Program membership, on the grounds that HealthKit is a paid-programme entitlement and
free provisioning "gives you no HealthKit at all." Because enrolment takes several days,
that claim put a multi-day purchase-and-wait on the critical path of the only remaining
gate — and that clock had not been started.

**The claim appears to be wrong.** Apple's
[capabilities table](https://developer.apple.com/support/app-capabilities/) — the page
Apple staff point to for exactly this question — lists three membership columns (Apple
Developer Program, Apple Developer Enterprise Program, and the free **Apple Developer**
account) and marks **HealthKit available in all three**. The neighbouring row,
*HealthKit Estimate Recalibration*, is marked paid-only, which is what a genuine paid
restriction looks like on that page. Spike A does not use recalibration.

The likely origin of the old claim is
[this forum thread](https://developer.apple.com/forums/thread/125980), where a
*university team* account refused the HealthKit capability while the same person's
personal account built the sample fine. That is an education-account limit being read as
a free-tier one.

Two facts are unchanged and not in dispute: HealthKit still does not work meaningfully in
the Simulator, so a physical iPhone is still required; and free-tier signing still
expires after 7 days.

## Decision

**Do not buy the membership to unblock Spike A. Run a ten-minute signing gate first —
free Personal Team, HealthKit capability, ⌘R onto the phone — and buy the account only
if a signing error names the HealthKit capability.** Buy it regardless before the 21-day
dogfood run in Phase 1, and before TestFlight.

Procedure: [the ten-minute gate](../../spikes/healthkit/README.md#the-ten-minute-gate).

## Trade-off accepted

**We are acting on a documentation table rather than a build that ran.** Apple's page is
authoritative about entitlement eligibility but says nothing about how Xcode's automatic
signing behaves for a Personal Team, which is where free provisioning historically breaks
in ways the table does not predict. If the gate fails, the several-day enrolment wait
starts ten minutes later than it would have — a small, bounded cost, and the reason the
gate is a gate rather than an assumption.

**The 7-day expiry is a real bill, later.** A free-signed build stops launching a week
after install. For a 90-minute spike that is nothing. For Phase 1's 21-consecutive-day
dogfood run it means plugging the phone in every week, and one forgotten re-sign is a
hole in the streak data the ranking engine is being validated against. The membership is
deferred, not avoided, and Phase 1 is where deferring it stops being free.

**A wrong claim sat in the repo for the length of Phase 0 and shaped its sequencing.**
The cost already paid is that Spike A — the one gate that can kill the project — was
parked behind a purchase nobody made, while unblocked work absorbed the time.

## Reversal trigger

Xcode refuses to sign a HealthKit build with a Personal Team, with an error naming the
capability (e.g. *"Personal development teams do not support the HealthKit
capability"*). Record the exact string in
[`07-spike-findings.md`](../phase-0/07-spike-findings.md), buy the membership, and this
ADR is reversed by measurement rather than by argument.

Also reversed by: Apple changing the capabilities table to move HealthKit out of the free
column, or the 7-day expiry proving disruptive earlier than the dogfood run.
