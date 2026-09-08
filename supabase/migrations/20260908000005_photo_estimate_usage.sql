-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — migration 005: the per-user daily cap on photo estimates.
--
-- §10 asks for this before the app is handed to anyone rather than after a
-- surprise bill. The measured cost is $0.000862 an image (Phase 0), so at any
-- honest rate of use this is not a cost control at all — it is an abuse control,
-- and specifically a bound on a runaway client loop. Thirty a day is generous
-- enough that nobody logging real meals reaches it and small enough that a bug
-- retrying in a loop costs pennies rather than a month's budget.
--
-- ─── Why a ledger and not a count of photo_estimates ───────────────────────
--
-- The obvious implementation is `select count(*) from photo_estimates where
-- user_id = ... and created_at::date = today`. It does not work, and the reason
-- is the thing this cap exists for: a `photo_estimates` row is only written when
-- the user CONFIRMS on Under Review. An estimate the user abandons — or one a
-- looping client never shows anybody — costs a model call and leaves no row, so
-- counting confirmations would count exactly the requests that are not the
-- problem and miss exactly the ones that are.
--
-- So the ledger counts REQUESTS, is written by the Edge Function under the
-- service role, and is claimed atomically before the model is called.
--
-- ─── Why there is no local @Model for this table ───────────────────────────
--
-- It is server-side state that the client is never allowed to author. A phone
-- that could write its own quota row would be a phone that could raise its own
-- cap, which is the definition of a client-side limit. `authenticated` gets
-- SELECT and nothing else, so the app can show how many are left; every write
-- goes through the function below. `scripts/check_schema_parity.py` reads
-- migration 001 and maps the tables that DO have models, so this needs no entry.
-- ═══════════════════════════════════════════════════════════════════════════

create table photo_estimate_usage (
  user_id    uuid not null references auth.users (id) on delete cascade,
  -- The user's local day is not knowable here, and it does not need to be: a
  -- cap is a rate limit, not a scoring window, so a UTC day is the right unit
  -- and the boundary landing at 1am British Summer Time costs nobody anything.
  -- The 21-day clock uses the user's calendar, because that one IS a scoring
  -- window; these are different questions and the difference is deliberate.
  day        date not null default (now() at time zone 'utc')::date,
  requests   integer not null default 0 check (requests >= 0),
  updated_at timestamptz not null default now(),

  primary key (user_id, day)
);

create trigger photo_estimate_usage_updated_at
  before update on photo_estimate_usage
  for each row execute function set_updated_at();

alter table photo_estimate_usage enable row level security;

-- Read your own, and that is all. There is deliberately no insert, update or
-- delete policy: with RLS on and no policy a write denies, which is the safe
-- direction to fail and the whole reason the cap is server-side.
create policy photo_estimate_usage_select on photo_estimate_usage
  for select to authenticated using (user_id = auth.uid());

grant select on photo_estimate_usage to authenticated;
revoke all on photo_estimate_usage from anon;

-- ─── The claim ─────────────────────────────────────────────────────────────
-- Test and increment in ONE statement. Two statements — read the count, then
-- write it — is a race that two concurrent requests both win, and the client
-- that a cap exists to bound is precisely the one making concurrent requests.
--
-- `on conflict ... do update ... where` is what makes it atomic: when the WHERE
-- fails the update does not happen and no row is returned, so "already at the
-- cap" and "claimed" are distinguished by whether there is a row rather than by
-- a second query.

create or replace function claim_photo_estimate(p_user uuid, p_cap integer)
returns integer
language plpgsql
security definer
-- Pinned. A SECURITY DEFINER function with a caller-controlled search_path is
-- the classic Postgres privilege-escalation shape.
set search_path = public, pg_temp
as $$
declare
  claimed integer;
begin
  insert into photo_estimate_usage (user_id, day, requests)
  values (p_user, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day) do update
    set requests = photo_estimate_usage.requests + 1
    where photo_estimate_usage.requests < p_cap
  returning requests into claimed;

  -- Null means the WHERE refused: the row exists and is already at the cap.
  return coalesce(claimed, -1);
end;
$$;

-- Only the service role calls this. A signed-in client that could call it could
-- burn its own quota, which is harmless, but the function is SECURITY DEFINER
-- and the smallest surface is the right one.
revoke all on function claim_photo_estimate(uuid, integer) from public;
revoke all on function claim_photo_estimate(uuid, integer) from anon, authenticated;
