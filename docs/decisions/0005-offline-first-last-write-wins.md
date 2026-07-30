# ADR 0005 — Offline-first with SwiftData; last-write-wins conflict resolution

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §04

## Context

Gyms have no signal. Restaurant basements have no signal. Aeroplanes have no signal.
These are not edge cases — they are precisely where and when people log food.

If logging fails offline, the user learns the app is unreliable at exactly the moment
they were building a habit, and they churn. §04 calls this one of the highest-leverage
decisions in the whole build, and that is not an overstatement: it is the difference
between an app that survives week two and one that does not.

Conflicts are possible but rare in this data model. A single user on a single device
is the overwhelming majority case; genuine concurrent conflict requires the same user
editing the same log on two devices while both are offline.

## Decision

**SwiftData is the local source of truth.** The UI never waits on the network — a log
is written locally and rendered immediately, always.

A `sync_outbox` table holds pending mutations (`entity`, `entity_id`, `operation`,
`payload`, `created_at`, `attempts`). A sync service drains it when connectivity
returns.

**Last-write-wins using server timestamps** for v1.

## Trade-off accepted

Last-write-wins can lose an edit. If the same food log is edited on two offline
devices, the later server timestamp wins silently and the other edit is gone.

This is accepted and **documented rather than solved.** CRDTs are the correct general
answer and entirely the wrong answer here: they are weeks of work to protect against
a scenario that requires two devices, both offline, editing the same row.

*Knowing when not to over-engineer is itself a signal of judgement* — and being able
to articulate exactly which conflict class is unhandled, and why that was the right
call, is a stronger interview answer than having built the CRDT.

## Interaction with the 48-hour edit lock

Worth noting because the two decisions help each other: the retroactive edit lock from
§2.3 (`food_logs.locked_at`, no edits after 48 hours) also bounds the window in which
a conflict is possible at all. An anti-gaming rule turns out to shrink the conflict
surface as a side effect.

## Reversal trigger

Phase 3 produces an actual report of lost data from a real user. Record the report.

Note that a *theoretical* conflict found while reasoning about the system is not the
trigger — the trigger is a user losing something they noticed.
