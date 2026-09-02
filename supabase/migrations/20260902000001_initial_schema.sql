-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — migration 001: the whole schema, with RLS on from the first line.
--
-- §1.1 refuses to defer RLS, and ADR 0003 says why in one sentence: the
-- publishable key ships in the app bundle and is public by design, so RLS is
-- not defence-in-depth — it IS the security boundary. A table without a policy
-- is a public table, and by week three this database holds real health data
-- that is special category under UK GDPR Article 9.
--
-- Every table here therefore ends with ENABLE ROW LEVEL SECURITY. With RLS on
-- and no policy a table denies everything, which is the safe direction to fail;
-- the policies arrive in migration 002.
--
-- Ten tables. Eight are live in Phase 1. `friendships` and `leaderboard_entries`
-- ship empty because nothing writes to them until Phase 4 — retrofitting
-- relationships into a live database holding real user data is the painful
-- version of this, and two empty tables cost nothing.
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists "pgcrypto";     -- gen_random_uuid()

-- ─── Enumerations ──────────────────────────────────────────────────────────
-- Enums rather than free text: these sets are genuinely fixed, and a typo in a
-- `source` column is the kind of bug that is invisible until a query silently
-- returns nothing. ALTER TYPE ... ADD VALUE covers the case where one grows.

create type food_source as enum ('off', 'usda', 'custom');
create type entry_method as enum ('manual', 'search', 'barcode', 'photo');
create type weight_source as enum ('manual', 'healthkit');
create type outbox_operation as enum ('insert', 'update', 'delete');
create type goal_type as enum ('lose', 'maintain', 'gain');

-- 'unspecified' is not a placeholder for missing data — it is a real answer to
-- a question the user is allowed to decline. S1 pairs it with the HIGHER
-- calorie floor (1,500), because erring high is the safe direction.
create type sex as enum ('female', 'male', 'unspecified');

create type activity_level as enum (
  'sedentary', 'light', 'moderate', 'active', 'very_active'
);

-- Fixed thresholds in v1 (ADR 0007). The ladder order is the enum order.
create type tier as enum ('bronze', 'silver', 'gold', 'platinum', 'diamond');

-- ─── Last-write-wins plumbing ──────────────────────────────────────────────
-- ADR 0005 resolves conflicts by SERVER timestamp. That word is doing real
-- work: a client-supplied `updated_at` would let a device with a wrong clock —
-- or a patched binary — win every conflict. The trigger overwrites whatever the
-- client sent, so the column cannot be forged.

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ─── profiles ──────────────────────────────────────────────────────────────
-- One row per user, keyed to auth.users so a deleted account takes its profile
-- with it rather than leaving an orphan holding a date of birth.

create table profiles (
  id                       uuid primary key references auth.users (id) on delete cascade,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  -- §10 S4: the age gate is computed from an actual date, never a year
  -- subtraction — someone turning 18 tomorrow is 17 today.
  dob                      date,
  height_cm                numeric(5, 1) check (height_cm > 0 and height_cm < 300),
  sex                      sex not null default 'unspecified',
  activity_level           activity_level not null default 'sedentary',

  goal_type                goal_type not null default 'lose',
  -- §10 S2: rejected, never clamped, if its BMI would fall below 18.5. The app
  -- refuses and says what the lowest acceptable value is; silently substituting
  -- a different goal would be dishonest about what is being tracked toward.
  goal_weight_kg           numeric(5, 2) check (goal_weight_kg > 0 and goal_weight_kg < 500),
  -- §10 S3: min(1.0 kg/week, 1% of body weight/week). The ceiling depends on
  -- current weight, so it is enforced in the app rather than as a constant here;
  -- this bound only catches the absurd.
  target_rate_kg_per_week  numeric(4, 2) not null default 0.5
                             check (target_rate_kg_per_week >= 0 and target_rate_kg_per_week <= 1.0),

  -- The first 14 days establish a baseline and no rank is shown until it closes
  -- ("CALIBRATING · N days to go"). Null means still calibrating.
  calibration_completed_at timestamptz,

  -- §10 S6: one switch that disables every competitive and social feature while
  -- leaving the tracker fully useful. An opt-out that cripples the app is not an
  -- opt-out, it is a threat.
  competitive_opt_out      boolean not null default false,

  -- §10 / UK GDPR Article 9. Health data needs EXPLICIT consent recorded
  -- separately from terms acceptance — one checkbox covering both is not
  -- explicit consent to anything. Two columns because they are two decisions.
  terms_accepted_at        timestamptz,
  health_consent_at        timestamptz
);

create trigger profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

alter table profiles enable row level security;

-- ─── foods ─────────────────────────────────────────────────────────────────
-- The shared catalogue: Open Food Facts and USDA mirrored locally, plus each
-- user's own custom entries. Deliberately NOT user-scoped for reads — a food
-- table only one person can see is a food table nobody benefits from — so its
-- policies are the one place in this schema that differ in shape.
--
-- §1.3: never call a third-party API on every keystroke. It is slow,
-- rate-limited, and fails offline, which is exactly when people log food.

create table foods (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  source         food_source not null,
  -- Set only for source = 'custom'. Null for the public mirror, which belongs
  -- to nobody; the policies in 002 lean on exactly that distinction.
  created_by     uuid references auth.users (id) on delete cascade,

  barcode        text,
  name           text not null check (length(trim(name)) > 0),
  brand          text,

  kcal_per_100g  numeric(7, 2) not null check (kcal_per_100g >= 0),
  protein_g      numeric(6, 2) check (protein_g >= 0),
  carbs_g        numeric(6, 2) check (carbs_g >= 0),
  fat_g          numeric(6, 2) check (fat_g >= 0),

  -- Maintained by trigger rather than a generated column: to_tsvector with a
  -- named configuration is only STABLE, not IMMUTABLE, so Postgres will not
  -- accept it in `generated always as`.
  search_vector  tsvector,

  constraint custom_foods_have_an_owner check (
    (source = 'custom' and created_by is not null) or
    (source <> 'custom' and created_by is null)
  )
);

create or replace function foods_search_vector()
returns trigger
language plpgsql
as $$
begin
  -- Name outranks brand: someone searching "hummus" wants hummus, not every
  -- product made by a company with hummus in its name.
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(new.brand, '')), 'B');
  return new;
end;
$$;

create trigger foods_search_vector
  before insert or update of name, brand on foods
  for each row execute function foods_search_vector();

create trigger foods_updated_at
  before update on foods
  for each row execute function set_updated_at();

create index foods_search_vector_idx on foods using gin (search_vector);
-- Partial: only packaged food has a barcode, and the lookup is always for one.
create index foods_barcode_idx on foods (barcode) where barcode is not null;
create index foods_custom_owner_idx on foods (created_by) where created_by is not null;

alter table foods enable row level security;

-- ─── food_logs ─────────────────────────────────────────────────────────────

create table food_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  food_id       uuid references foods (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  logged_at     timestamptz not null,
  grams         numeric(8, 2) not null check (grams > 0),
  entry_method  entry_method not null,

  -- §2.3 anti-gaming: a log cannot be edited more than 48 hours after the fact.
  -- Derived from logged_at by trigger, never accepted from the client, so it
  -- cannot be moved; the update policy in 002 enforces it in the database
  -- rather than trusting the app. ADR 0005 notes the happy side effect — this
  -- also bounds the window in which an offline last-write-wins conflict is
  -- possible at all.
  --
  -- A trigger rather than `generated always as`: adding an interval to a
  -- timestamptz depends on the session TimeZone, so Postgres rates it STABLE
  -- and refuses it in a generated column.
  locked_at     timestamptz not null,

  -- Denormalised so a log survives its food being deleted or a mirror refresh
  -- rewriting the catalogue. A logged day must stay readable forever; the 21-day
  -- clock is the whole point of Phase 1 and it cannot depend on a foreign row.
  kcal          numeric(8, 2) not null check (kcal >= 0),
  name_snapshot text not null
);

create or replace function food_logs_set_lock()
returns trigger
language plpgsql
as $$
begin
  new.locked_at := new.logged_at + interval '48 hours';
  return new;
end;
$$;

create trigger food_logs_set_lock
  before insert or update of logged_at on food_logs
  for each row execute function food_logs_set_lock();

create trigger food_logs_updated_at
  before update on food_logs
  for each row execute function set_updated_at();

create index food_logs_user_logged_at_idx on food_logs (user_id, logged_at desc);

alter table food_logs enable row level security;

-- ─── photo_estimates ───────────────────────────────────────────────────────
-- ADR 0010: an estimate is never silently accepted. `was_corrected` and
-- `correction_delta` are not analytics — §1.3 calls this dataset a real
-- proprietary asset, and it is how the prompt gets better later.

create table photo_estimates (
  id               uuid primary key default gen_random_uuid(),
  log_id           uuid not null references food_logs (id) on delete cascade,
  user_id          uuid not null references auth.users (id) on delete cascade,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- Path inside the private meal-photos bucket. The object itself is never
  -- public; reads go through a short-expiry signed URL.
  storage_path     text not null,
  model_output     jsonb not null,
  -- 0..1. Surfaced as HIGH / MEDIUM / LOW — a range and a confidence, never a
  -- single number presented as fact.
  confidence       numeric(3, 2) check (confidence >= 0 and confidence <= 1),

  was_corrected    boolean not null default false,
  correction_delta numeric(8, 2)
);

create trigger photo_estimates_updated_at
  before update on photo_estimates
  for each row execute function set_updated_at();

create index photo_estimates_log_idx on photo_estimates (log_id);

alter table photo_estimates enable row level security;

-- ─── weight_logs ───────────────────────────────────────────────────────────

create table weight_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  measured_at timestamptz not null,
  kg          numeric(5, 2) not null check (kg > 0 and kg < 500),
  source      weight_source not null default 'manual',

  -- One reading per source per instant. A smart scale writing to HealthKit and
  -- the app reading it back must not produce two rows for one weigh-in.
  unique (user_id, measured_at, source)
);

create trigger weight_logs_updated_at
  before update on weight_logs
  for each row execute function set_updated_at();

create index weight_logs_user_measured_at_idx on weight_logs (user_id, measured_at desc);

alter table weight_logs enable row level security;

-- ─── health_samples ────────────────────────────────────────────────────────
-- One row per user per day, already bucketed. Phase 0 measured ~1,830 step
-- samples and ~3,000 active-energy samples PER DAY on a real device: iterating
-- raw samples for a daily total is the mistake this table exists to prevent.
-- HKStatisticsCollectionQuery buckets inside HealthKit and returns 31 values
-- instead of 56,764 objects.

create table health_samples (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- The user's local calendar day, not a timestamp. A day is what HealthKit
  -- buckets by and what the score counts.
  date             date not null,
  steps            integer check (steps >= 0),
  active_energy    numeric(8, 2) check (active_energy >= 0),
  exercise_minutes integer check (exercise_minutes >= 0),
  workout_count    integer not null default 0 check (workout_count >= 0),

  -- The persisted HKAnchoredObjectQuery anchor. §1.4 calls this "the entire
  -- trick": without it every cold start re-queries full history, which measured
  -- as a four-second hang on a device with two years of data.
  hk_anchor        bytea,

  unique (user_id, date)
);

create trigger health_samples_updated_at
  before update on health_samples
  for each row execute function set_updated_at();

alter table health_samples enable row level security;

-- ─── weekly_scores ─────────────────────────────────────────────────────────
-- Phase 2 computes these. The table exists now so the shape is settled.

create table weekly_scores (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  week_start     date not null,
  consistency    numeric(4, 3) check (consistency >= 0 and consistency <= 1),
  adherence      numeric(4, 3) check (adherence >= 0 and adherence <= 1),
  progress       numeric(4, 3) check (progress >= 0 and progress <= 1),
  composite      numeric(4, 3) check (composite >= 0 and composite <= 1),
  tier           tier,

  -- Not optional, and the brief is emphatic about why: retune the weights — and
  -- you will — and without this every historical score becomes meaningless,
  -- because you cannot tell which version produced which number.
  engine_version text not null,

  -- §2.3 plausibility flags. Flag, never reject: over-aggressive rejection
  -- destroys trust with honest outliers, and there are always more of those
  -- than cheats.
  flags          jsonb not null default '{}'::jsonb,

  unique (user_id, week_start)
);

create trigger weekly_scores_updated_at
  before update on weekly_scores
  for each row execute function set_updated_at();

alter table weekly_scores enable row level security;

-- ─── sync_outbox ───────────────────────────────────────────────────────────
-- ADR 0005's pending-mutation queue.
--
-- Worth being straight about: the outbox's real home is the on-device SwiftData
-- store, because its entire purpose is holding writes that have NOT reached the
-- server. A server-side copy is inert by construction — a row only exists here
-- once it no longer needs to. It is in the schema because the brief's data
-- model lists it and because the local and remote models are specified to
-- mirror each other, which is worth more than saving one empty table.

create table sync_outbox (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),

  entity     text not null,
  entity_id  uuid not null,
  operation  outbox_operation not null,
  payload    jsonb not null,
  attempts   integer not null default 0 check (attempts >= 0)
);

create index sync_outbox_user_created_idx on sync_outbox (user_id, created_at);

alter table sync_outbox enable row level security;

-- ─── friendships · leaderboard_entries ─────────────────────────────────────
-- Phase 4. Empty on purpose, created now because retrofitting relationships
-- into a live database holding real health data is the expensive version.

create table friendships (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  requester_id uuid not null references auth.users (id) on delete cascade,
  addressee_id uuid not null references auth.users (id) on delete cascade,
  status       text not null default 'pending'
                 check (status in ('pending', 'accepted', 'blocked')),

  constraint no_self_friendship check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create trigger friendships_updated_at
  before update on friendships
  for each row execute function set_updated_at();

alter table friendships enable row level security;

create table leaderboard_entries (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  user_id    uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  composite  numeric(4, 3) check (composite >= 0 and composite <= 1),
  tier       tier,
  rank       integer check (rank > 0),

  unique (user_id, week_start)
);

alter table leaderboard_entries enable row level security;
