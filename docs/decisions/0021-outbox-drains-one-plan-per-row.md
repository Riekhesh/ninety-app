# 0021 · The outbox drains one plan per row, and only a refusal costs an attempt

**Status:** Locked · **Phase:** 1 · **Date:** 10 September 2026

## Context

[ADR 0005](0005-offline-first-last-write-wins.md) settled the shape of offline-first in
Phase 0: SwiftData is the local source of truth, a `sync_outbox` table holds pending
mutations, a sync service drains it when connectivity returns, and conflicts resolve
last-write-wins on **server** timestamps. Migration 001 built the table and the
`set_updated_at` trigger, and P1-B made every repository enqueue.

Nothing has ever read those notes. Until P1-I the outbox was a queue that only grew, and
the Phase 1 exit criterion — *"outbox sync verified in airplane mode"* — could not be
attempted because there was nothing to verify.

ADR 0005 does not say how a drain behaves, and four questions have to be answered before
one can be written. None of them is a detail:

1. **What does a sequence of edits to one row mean?** A meal logged on the Underground,
   corrected at the ticket barrier and corrected again on the bus is three outbox
   entries describing one row.
2. **In what order does a batch go up?** `food_logs.food_id` references `foods` and
   `photo_estimates.log_id` references `food_logs`. A batch sent in the order the user
   made it violates a foreign key roughly whenever somebody adds a custom food and
   logs it.
3. **What counts as a retry?** `sync_outbox.attempts` exists and has never been
   incremented. The obvious reading — one attempt per failed request — is wrong here in
   a way that matters, and the reason is the clock.
4. **When does it stop?** A row the server will never accept must not be retried until
   the end of time, and must not be deleted either.

The third question is the one that turns a plumbing decision into a product one. **The
21-day clock has been running since 9 September**, and the repo's standing rule is that a
change which breaks a day's logging is a fix-now bug because it resets a counter costing
three weeks to rebuild. A drain that spends attempts on a failed connection would take a
week logged on a plane and land it at the gate already parked.

## Decision

**Four rules, in `OutboxDrain` and `SyncService`.**

**1 · One plan per row, not one request per entry.** Entries are grouped by
`(entity, entity_id)` and collapse to a single write whose payload is read from the
current local row at drain time. `Outbox.enqueue` has always written `{}` as its payload
and said why in its doc comment; this is where that promise is kept. A sequence
collapses like this:

| Queued | Sent |
|---|---|
| insert, update, update | **upsert** — the row in its final state |
| update, update | **upsert** |
| insert, update, delete | **delete** |
| update, delete | **delete** |

The middle column matters more than it looks. *Any* insert in the sequence wins over a
later update, because a row created and edited offline has never been seen by the server
— and a `PATCH` matching nothing succeeds quietly, so treating it as an update would
leave the meal missing from the server while the phone displayed it perfectly.

**2 · Upserts in dependency order; deletes in the reverse of it.** `profiles` → `foods`
→ `food_logs` → `photo_estimates` on the way up, and the opposite on the way down, with
oldest-first inside a rank. Every write is an upsert (`Prefer: resolution=merge-duplicates`)
against the primary key, except `weight_logs` and `health_samples`, which resolve
against their natural keys — `(user_id, measured_at, source)` and `(user_id, date)`.
Those two are the reinstall case: a restored phone re-reads Apple Health and mints new
local ids for the same weigh-ins, and resolving on `id` would insert a second row for a
weight that already exists.

**3 · Only a refusal of the row costs the row an attempt.** Failures split by whose
fault they are.

- *About the connection* — no network, no session, 5xx, 429. The drain **stops** where
  it is, records nothing against anything, and backs off (2s doubling to a 5-minute
  ceiling, cancelled immediately by a reconnect). None of the queue is charged for a
  radio that was not there.
- *About the row* — 400, 403, 409, 422. `attempts` increments on every entry in the
  group and the drain carries on to the next row.

**4 · Five refusals and it stops asking.** The unit is parked: kept, never deleted,
counted, and shown in Settings with a control that resets the count and tries again. An
entry whose `entity` this build cannot map is counted the same way rather than discarded
— an unreadable note is still a record that something was written.

**Two writes are dropped deliberately rather than sent**, and both are logged by name so
a queue that empties without sending anything can be explained afterwards. A queued
insert whose local row no longer exists — created and deleted offline, or cascaded away
with its parent — describes something that does not exist. And a correction to a
`food_logs` row that reaches the front of the queue after §2.3's 48-hour window has
closed is dropped rather than sent to be refused five times: the rule is what bounds the
window in which a last-write-wins conflict is possible at all, and ADR 0005 already
counts that as a happy side effect.

## The trade-off, knowingly accepted

**This is a push, not a restore.** Nothing reads a row back down. The server copy
protects the 21 days against a lost or replaced phone, and does not yet repopulate a new
one — so a reinstall still asks for consent a second time, which `RootView` has been
saying it would stop doing since P1-C. Pulling is a different decision with a different
conflict story: last-write-wins against a device holding no rows is indistinguishable
from a wipe, and getting that wrong deletes exactly the data this ticket exists to
protect. It is not what the exit criterion asks for and it is not in this ADR.

**A delete that arrives after the lock leaves the two stores disagreeing.** RLS `using`
clauses filter rather than raise, so a `food_logs` delete the server will not serve
returns 204 with nothing removed. The phone forgets the row and the server keeps it. The
drain cannot tell, and the alternative — treating a successful response as a failure —
would retry forever. Phase 2 reads its test set from the phone, so the divergence costs
nothing today; it is written down here rather than discovered then.

**Coalescing loses intermediate states.** Three corrections to one meal reach the server
as one row in its final shape. That is the point, and it is also the acceptance of a
smaller version of ADR 0005's trade-off: the intermediate values were never anything but
a user changing their mind, and replaying three versions at the server would only give
last-write-wins more to arbitrate.

## What was considered and rejected

**One request per outbox entry, replayed in order.** The naive reading, and it is worse
on every axis: three requests where one would do, on the connection that is usually the
problem, and it hands the server a sequence to arbitrate that the client already knows
the answer to.

**`PATCH` for updates and `POST` for inserts.** Correct-looking and quietly lossy. A
`PATCH` that matches no rows returns success, so a row whose insert never left the phone
would be silently absent from the server. One upsert path is idempotent whether the row
is there or not, which is also what makes a replayed drain harmless.

**Backing off per row rather than per connection.** The dominant failure is global — a
basement, a plane, a tunnel — and a per-row backoff would be sixty timers describing one
radio.

**Retrying a parked row forever, or on a timer.** A row refused five times is refused
for a reason. The honest thing is to say so and let the person decide, not to keep
asking on their behalf and call it resilience.

**Deleting an entry this build cannot map.** It would keep the queue tidy by throwing
away the only evidence that something was written.

**A count of unsent rows on Matchday.** Rejected on the design principles: §04's whole
decision is that the app behaves as though the network does not exist, and a badge
counting plumbing on the screen someone opens to log breakfast is that decision leaking
into the product. The count lives in Settings, where it is an instrument rather than an
interruption — and the airplane-mode exit criterion needs an instrument, because
"reconciled cleanly" is not visible in a list of meals that looks identical either way.

## Reversal trigger

Revisit rule 3 — the split between a refusal and a connection failure — if the dogfood
period produces **a parked row whose cause was a connection**, i.e. a row that arrives at
five attempts without the server ever having answered. That would mean the `URLError`
mapping is wrong, and it is a log line away from being provable.

Revisit rule 1 if a real conflict is observed that coalescing caused: two devices, both
offline, and a lost edit that the user noticed. Note ADR 0005's own wording — a
*theoretical* conflict found while reasoning about the system is not the trigger.

Build the pull half when there is a second device or a restored phone that has to come
back with its history, which is a Phase 3 problem at the earliest. Not before: an unused
restore path is a data-destroying code path nobody has exercised.

## Consequences

| Where | Change |
|---|---|
| `Ninety/Sync/` | The whole layer: the plan, the payload, the client, the service |
| `Ninety/Sync/SyncTable.swift` | Where `OutboxEntry.tableName` finally becomes `sync_outbox.entity` |
| `Ninety/Features/Settings/SyncPanel.swift` | The only surface, and the airplane-mode instrument |
| `Ninety/App/RootView.swift` · `MainTabView.swift` | The service is built per signed-in user; the stale P1-I note is corrected. The shell split off a 400-line limit |
| `scripts/check_schema_parity.py` | Every column the drain sends is checked against migration 001 |
| `NinetyTests/SyncPlanTests.swift` · `SyncTests.swift` | This ADR as assertions |
