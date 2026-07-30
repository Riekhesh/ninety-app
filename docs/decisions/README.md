# Decision log

> *The point of writing these down is so you stop arguing with yourself at 1am in
> week six.* — §02

Each decision is one file: the context, the call, the trade-off knowingly accepted,
and — most importantly — **the specific thing that would have to happen for the
decision to be reversed.**

## The reversal protocol

A locked decision can be reversed. It cannot be reversed *silently*, and it cannot be
reversed on a feeling.

To reverse one, append a `## Reversed` section to its file stating **what new
information changed it.** "I changed my mind" is not new information. Real triggers
look like:

- a TestFlight metric
- a technical blocker you actually hit, with the error
- an Apple policy change
- a measured number that contradicts an assumption in the ADR

Every ADR below carries a pre-written **reversal trigger** — the condition that
*would* justify revisiting it. Writing that condition down at decision time is the
whole trick: it converts "am I sure?" from an anxiety into a test.

Re-litigating settled decisions is the most expensive habit in solo projects.

---

## Index

| # | Decision | Status | Phase |
|---|---|---|---|
| [0001](0001-native-swift-not-react-native.md) | Native Swift / SwiftUI, not React Native | Locked | 0 |
| [0002](0002-ios-18-deployment-target.md) | iOS 18.0 deployment target, iOS 26 SDK | Locked | 0 |
| [0003](0003-supabase-backend.md) | Supabase as backend | Locked | 0 |
| [0004](0004-mvvm-observation-not-tca.md) | MVVM with `@Observable`, not TCA | Locked | 0 |
| [0005](0005-offline-first-last-write-wins.md) | Offline-first, last-write-wins for v1 | Locked | 0 |
| [0006](0006-ranking-engine-client-side-first.md) | Ranking engine ships client-side first | Locked | 0 |
| [0007](0007-fixed-tier-thresholds.md) | Fixed tier thresholds, not percentiles | Locked | 0 |
| [0008](0008-consistency-weighted-above-progress.md) | Consistency weighted above progress | Locked | 0 |
| [0009](0009-no-workout-logging-in-v1.md) | No workout logging in v1 | Locked | 0 |
| [0010](0010-anthropic-as-vision-provider.md) | Anthropic as the vision provider, behind an interface | Locked | 0 |
| [0011](0011-dark-first-visual-direction.md) | Quiet premium, dark-first visual direction | Locked | 0 |
| [0012](0012-tier-encoded-as-notch-count.md) | Tier encoded as notch count, not colour alone | Locked | 0 |

New decisions get the next number. Do not renumber; a stale link is worse than a gap.
