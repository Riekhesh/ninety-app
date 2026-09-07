-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — migration 002: row-level security policies.
--
-- Migration 001 turned RLS on and stopped there, which denies everything. This
-- file is what decides who may see what, and it is the ONLY thing standing
-- between account A and account B's health data: the publishable key ships in
-- the app bundle and is public by design (ADR 0003), so a policy bug here is a
-- data breach, not a bug.
--
-- Two habits throughout, both deliberate:
--
--   · Every policy names `authenticated`. Nothing in this schema is readable
--     signed out, including the food catalogue.
--   · Every policy spells out BOTH `using` and `with check` where the command
--     takes them. `using` decides which rows you may touch; `with check`
--     decides what a row may look like afterwards.
--
--     Belt and braces rather than strictly required, and it is worth being
--     precise about why, because the obvious reason is wrong. Omitting
--     `with check` does NOT leave the new row unchecked: Postgres reuses the
--     `using` expression as the check. And a reassignment — taking one of your
--     own rows and setting user_id to somebody else — is refused even by a
--     policy whose check is literally `true`, because Postgres also applies
--     SELECT policies to the post-update row, so a row cannot be edited into a
--     state where it would become invisible to you.
--
--     Both are verified in supabase/tests/rls_two_accounts.sql rather than
--     taken on trust. They are written out anyway because a reviewer should be
--     able to read the intent off the policy instead of deriving it from two
--     interacting defaults.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Table privileges ──────────────────────────────────────────────────────
-- RLS narrows a grant; it cannot create one. Without these the policies below
-- are unreachable and every query fails on permission before RLS is consulted.
--
-- The revoke is not paranoia. A Supabase project ships ALTER DEFAULT PRIVILEGES
-- granting ALL on new public tables to anon as well as authenticated, so a
-- table created by a migration is granted to the signed-out role automatically.
-- RLS still denies it — there is no anon policy anywhere in this file — but a
-- grant that is only ever load-bearing if a policy is wrong is a grant worth
-- not having.
--
-- Named tables rather than ALL TABLES IN SCHEMA public: this runs against a
-- live project, and a blanket revoke would also strip anything else that ever
-- ends up in `public`, including tables Supabase or a later migration adds.

revoke all on
  profiles, foods, food_logs, photo_estimates, weight_logs,
  health_samples, weekly_scores, sync_outbox, friendships, leaderboard_entries
  from anon;

grant select, insert, update, delete on
  profiles, food_logs, photo_estimates, weight_logs,
  health_samples, weekly_scores, sync_outbox, friendships
  to authenticated;

-- Foods is the shared catalogue: readable by everyone signed in, writable only
-- for your own custom entries.
grant select, insert, update, delete on foods to authenticated;

-- Phase 4 writes the leaderboard, server-side. Read-only until then.
grant select on leaderboard_entries to authenticated;

-- ─── profiles ──────────────────────────────────────────────────────────────
-- Keyed on `id` rather than `user_id`: the primary key IS the auth user.

create policy profiles_select on profiles
  for select to authenticated using (id = auth.uid());

create policy profiles_insert on profiles
  for insert to authenticated with check (id = auth.uid());

create policy profiles_update on profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy profiles_delete on profiles
  for delete to authenticated using (id = auth.uid());

-- ─── foods ─────────────────────────────────────────────────────────────────
-- The one table whose read policy is not user-scoped, and deliberately so: a
-- food catalogue only its creator can see is a catalogue nobody benefits from.
-- Writes are a different question, and the `with check` on both insert and
-- update is what stops a user editing an Open Food Facts row that everybody
-- else also reads.

create policy foods_select on foods
  for select to authenticated using (true);

create policy foods_insert_own_custom on foods
  for insert to authenticated
  with check (source = 'custom' and created_by = auth.uid());

create policy foods_update_own_custom on foods
  for update to authenticated
  using (source = 'custom' and created_by = auth.uid())
  with check (source = 'custom' and created_by = auth.uid());

create policy foods_delete_own_custom on foods
  for delete to authenticated
  using (source = 'custom' and created_by = auth.uid());

-- ─── food_logs ─────────────────────────────────────────────────────────────

create policy food_logs_select on food_logs
  for select to authenticated using (user_id = auth.uid());

create policy food_logs_insert on food_logs
  for insert to authenticated with check (user_id = auth.uid());

-- §2.3's 48-hour edit lock, enforced by the database rather than by the app.
-- The copy deck states the rule to the user plainly — "Logs older than 48 hours
-- can't be edited. It keeps scores honest." — and a rule the user can see the
-- point of should not also be one a patched client can ignore.
create policy food_logs_update_before_lock on food_logs
  for update to authenticated
  using (user_id = auth.uid() and locked_at > now())
  with check (user_id = auth.uid());

create policy food_logs_delete_before_lock on food_logs
  for delete to authenticated
  using (user_id = auth.uid() and locked_at > now());

-- ─── photo_estimates ───────────────────────────────────────────────────────

create policy photo_estimates_select on photo_estimates
  for select to authenticated using (user_id = auth.uid());

create policy photo_estimates_insert on photo_estimates
  for insert to authenticated with check (user_id = auth.uid());

create policy photo_estimates_update on photo_estimates
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy photo_estimates_delete on photo_estimates
  for delete to authenticated using (user_id = auth.uid());

-- ─── weight_logs ───────────────────────────────────────────────────────────

create policy weight_logs_select on weight_logs
  for select to authenticated using (user_id = auth.uid());

create policy weight_logs_insert on weight_logs
  for insert to authenticated with check (user_id = auth.uid());

create policy weight_logs_update on weight_logs
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy weight_logs_delete on weight_logs
  for delete to authenticated using (user_id = auth.uid());

-- ─── health_samples ────────────────────────────────────────────────────────

create policy health_samples_select on health_samples
  for select to authenticated using (user_id = auth.uid());

create policy health_samples_insert on health_samples
  for insert to authenticated with check (user_id = auth.uid());

create policy health_samples_update on health_samples
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy health_samples_delete on health_samples
  for delete to authenticated using (user_id = auth.uid());

-- ─── weekly_scores ─────────────────────────────────────────────────────────
-- Readable and deletable by their owner; written by the engine. Client inserts
-- are allowed in Phase 1 because the engine runs on the device (ADR 0006), and
-- this is exactly the grant that has to close before Phase 4 ships a
-- leaderboard — a client-authoritative score is trivially cheatable with a
-- patched binary, which is fine while the only competitor is your past self.

create policy weekly_scores_select on weekly_scores
  for select to authenticated using (user_id = auth.uid());

create policy weekly_scores_insert on weekly_scores
  for insert to authenticated with check (user_id = auth.uid());

create policy weekly_scores_update on weekly_scores
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy weekly_scores_delete on weekly_scores
  for delete to authenticated using (user_id = auth.uid());

-- ─── sync_outbox ───────────────────────────────────────────────────────────

create policy sync_outbox_select on sync_outbox
  for select to authenticated using (user_id = auth.uid());

create policy sync_outbox_insert on sync_outbox
  for insert to authenticated with check (user_id = auth.uid());

create policy sync_outbox_update on sync_outbox
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy sync_outbox_delete on sync_outbox
  for delete to authenticated using (user_id = auth.uid());

-- ─── friendships ───────────────────────────────────────────────────────────
-- Phase 4, and empty until then. Policies exist now so the table is not
-- sitting there with RLS on and nothing written down about who should ever see
-- a row — the state where somebody later adds a permissive policy in a hurry.
--
-- Both sides can see the row; only the requester creates it; either side can
-- update it, which is what accepting and blocking are.

create policy friendships_select on friendships
  for select to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

create policy friendships_insert on friendships
  for insert to authenticated with check (requester_id = auth.uid());

create policy friendships_update on friendships
  for update to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid())
  with check (requester_id = auth.uid() or addressee_id = auth.uid());

create policy friendships_delete on friendships
  for delete to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- ─── leaderboard_entries ───────────────────────────────────────────────────
-- Own rows only, and that is not a placeholder for something looser. v1 shows
-- no other user's name, number or percentile anywhere; widening this is a
-- Phase 4 decision that has to be made deliberately, with the engine already
-- server-side.

create policy leaderboard_entries_select on leaderboard_entries
  for select to authenticated using (user_id = auth.uid());
