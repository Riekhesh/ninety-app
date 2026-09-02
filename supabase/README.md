# Supabase

Postgres, auth, storage (ADR 0003). **RLS is not defence-in-depth here — it is
the security boundary.** The publishable key ships in the app bundle and is
public by design, so a table without a policy is a public table, and by week
three this database holds real health data that is special category under UK
GDPR Article 9.

```
migrations/   applied in filename order by `supabase db push`
tests/        the local harness. NEVER applied to a project
```

## Verify

```bash
scripts/verify-rls.sh
```

Boots a throwaway Postgres, applies the migrations exactly as `db push` would,
and runs the two-account proof — 27 assertions covering read, update, delete,
forgery and reassignment across all ten tables plus the storage bucket. Runs in
CI on every PR that touches this directory.

## Apply to the project

```bash
supabase link --project-ref <ref>
supabase db push
```

`db push` reads `migrations/` only, which is why the stubs live under `tests/`:
they cannot reach a real project even by accident.

## The migrations

| | |
|---|---|
| `..._initial_schema.sql` | Ten tables, enums, indexes, triggers, and `enable row level security` on every one. RLS on with no policy denies everything, which is the safe direction to fail. |
| `..._rls_policies.sql` | Who may see what. Grants, per-table policies, the meal-photos bucket and its policies. |

Eight tables are live in Phase 1. `friendships` and `leaderboard_entries` ship
empty — nothing writes to them until Phase 4, and retrofitting relationships
into a live database holding real user data is the expensive version.

## Why the stubs exist

Supabase provides `auth.users`, `auth.uid()`, `storage.objects` and the
`anon` / `authenticated` roles. Vanilla Postgres does not, so without them the
migrations cannot be applied locally and the RLS cannot be tested at all.
`tests/00_local_supabase_stubs.sql` is the smallest set that makes the real
migrations run unmodified. The migrations are what ships; the stubs never leave
this machine.

## Not here yet

The Open Food Facts + USDA import. `foods` has its `search_vector` column and
GIN index, but the mirror itself is deferred — nothing in the minimum
daily-usable app needs it, and the 21-day clock is the one thing in Phase 1 no
effort compresses. It lands alongside P1-F's search route.
