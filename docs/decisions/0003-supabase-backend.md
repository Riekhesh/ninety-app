# ADR 0003 — Use Supabase (Postgres) as the backend

**Status:** Locked
**Date:** 2026-07-27
**Phase:** 0
**Brief reference:** §02, §04

## Context

The workloads this backend has to serve are, in order of importance:

1. Weekly score computation over a user's own history
2. Cohort and leaderboard queries in Phase 4
3. A food database of a few hundred thousand rows with full-text search
4. Auth, with Sign in with Apple
5. Object storage for meal photos
6. A server-side place to hold the vision model API key

Items 1–3 are inherently relational. Ranking a set of users by a computed score,
joining a user's logs to a food table, and text-searching that food table are all
things Postgres does natively and a document store does badly.

Item 6 matters more than it looks: it is the reason a backend exists at all in Phase 0
terms. The key cannot go in the app (ADR — see `docs/security/secrets.md`), so
*something* server-side has to hold it. Edge Functions are that something.

## Decision

Supabase: Postgres, Auth, Storage, Edge Functions. `supabase-swift` SDK on the client.

Row-Level Security enabled on every table from the **first** migration.

## Trade-off accepted

**Vendor lock-in on auth and edge functions.** Supabase's auth schema and its Deno
Edge Function runtime are not portable. If Supabase raised prices or shut down, those
two layers would be a rewrite.

Acceptable, because the part that actually matters — the health data — is portable
Postgres. `pg_dump` gets everything out.

**A second, sharper trade-off worth naming:** the anon key ships in the app bundle and
is public by design. That means RLS is not defence-in-depth, it is *the* security
boundary for special category health data. A table without a policy is a public table.
This is the reason §1.1 refuses to defer RLS, and the reason Phase 1's exit criteria
require testing it with two real accounts rather than assuming it.

## Reversal trigger

- Free tier limits hit before Phase 3 completes (unlikely — it comfortably covers
  Phases 0–3)
- Cost exceeds ~$25/month before there is any revenue
- A hard technical blocker in Edge Functions for the vision proxy, which is the one
  thing with no fallback

Record the specific limit hit and the observed usage number if this is reversed.
