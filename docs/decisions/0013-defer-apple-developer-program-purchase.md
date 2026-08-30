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

**The claim is wrong.** Apple's
[capabilities table](https://developer.apple.com/support/app-capabilities/) — the page
Apple staff point to for exactly this question — has three membership columns (ADP,
ADEP, and the free **Apple Developer** account). Parsed from the page's HTML rather
than read off a rendering:

```
HealthKit                          ADP ✓   ADEP ✓   Apple Developer ✓
HealthKit Estimate Recalibration   ADP ✓   ADEP ✓   Apple Developer ✗
```

**Exactly 9 of the 57 iOS capabilities are available to the free tier, and HealthKit is
one of them**: App groups, Background modes, Data protection, HealthKit, HomeKit,
Inter-App Audio, Keychain sharing, Maps, Wireless Accessory Configuration. The
neighbouring *Estimate Recalibration* row is paid-only — that is what a genuine paid
restriction looks like on this page — and Spike A does not use recalibration.

The narrowness of that list is why the old claim was plausible. It was still wrong.

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
if a signing error names the HealthKit capability.**

Procedure: [the ten-minute gate](../../spikes/healthkit/README.md#the-ten-minute-gate).

**The membership is deferred, not avoided.** From the same table, the first hard
deadline is earlier than it looks:

| Trigger | Why | When |
|---|---|---|
| **Sign in with Apple** | **ADP only — not even Enterprise.** [ADR 0003](0003-supabase-backend.md) puts it in Phase 1 auth, the first thing built | **Phase 1, week 1** |
| Push notifications | Free tier ✗ | Whenever notifications land |
| 21-day dogfood run | 7-day signing expiry; a missed re-sign is a hole in the streak data | Phase 1 |
| TestFlight, submission | No distribution on the free tier at all | Phase 2/3 |

So: **buy it during Phase 0's remaining Swift weeks, not to unblock Spike A.** The
enrolment wait then overlaps work that was never blocked on it, which is what §0.1 was
reaching for and the old claim got backwards — it put the purchase on the critical path
of the *gate* instead of the critical path of the *build*.

## Trade-off accepted

**We are acting on a documentation table rather than a build that ran.** Apple's page is
authoritative about entitlement eligibility but says nothing about how Xcode's automatic
signing behaves for a Personal Team, which is where free provisioning historically breaks
in ways the table does not predict. If the gate fails, the several-day enrolment wait
starts ten minutes later than it would have — a small, bounded cost, and the reason the
gate is a gate rather than an assumption.

**The saving is days, not dollars.** The $99 is still spent, and spent within Phase 0.
What this buys is that Spike A — the gate that can kill the project — stops waiting on
an enrolment queue. Anyone reading the decision as "we avoided the fee" has misread it.

**The 7-day expiry is a real bill if the purchase slips.** A free-signed build stops
launching a week after install; one forgotten re-sign during the 21-day dogfood run is a
hole in the streak data the ranking engine is being validated against.

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
