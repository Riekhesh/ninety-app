# ADR 0004 — MVVM with `@Observable`, not The Composable Architecture

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §04

## Context

The developer is new to Swift. TCA is a genuinely good architecture with a genuinely
steep learning curve: reducers, effects, dependency injection via its own system, and
a testing model that has to be learned separately from Swift Testing.

The app's state is not especially complex. Six screens, three tabs, one interesting
computation (which lives outside the architecture entirely — see ADR 0006).

## Decision

MVVM. `@Observable` ViewModels via the Observation framework. Protocol-based
repositories injected into ViewModels.

## Trade-off accepted

Less structural enforcement than TCA. Nothing stops a ViewModel from growing to 400
lines or a view from reaching around its ViewModel to a repository directly. SwiftLint
catches size; only discipline catches shape.

Loses TCA's exhaustive-by-default state testing. Mitigated by the thing that actually
matters being tested elsewhere: the ranking engine is pure and exhaustively tested on
its own terms.

## Why this is the right call for *this* project specifically

The learning tax is the whole argument. §10 names the "motivation wall at ~week 8" as
the single most likely cause of failure, and the term-time collision from
mid-September as the second. An architecture that costs three weeks to become
productive in spends the exact slack the plan needs for its highest-risk period.

Protocol-based repositories are the part worth keeping regardless — they are what make
the app testable at all, and being able to explain *why* a repository is a protocol is
worth more in an interview than knowing TCA's vocabulary.

## Reversal trigger

Not reversible mid-project; an architecture migration in Phase 2 or 3 would consume
the entire remaining budget.

If ViewModels become genuinely unmanageable, the correct response is to extract logic
into plain testable types — not to adopt a framework.
