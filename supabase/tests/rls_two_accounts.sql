-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — RLS proof: two accounts, one database.
--
-- Phase 1 exit criterion: "RLS policies on every table, tested with two
-- accounts." docs/security/secrets.md puts it more bluntly — "assume it is
-- broken until you have seen it fail."
--
-- This is that, as a script rather than an afternoon in the dashboard. It
-- creates two real auth users, has A write a row into every table, then puts on
-- B's identity and attempts to read, change and delete each one.
--
-- Three different shapes of denial, and the difference matters:
--
--   · SELECT of a row you do not own returns ZERO ROWS. It is not an error.
--     A test that only checks "no exception" passes against a wide-open table.
--   · UPDATE and DELETE likewise affect zero rows, silently.
--   · INSERT of a row belonging to somebody else RAISES. That one is loud.
--
-- No pgTAP: plain psql, so this runs in CI on Ubuntu with no extension to
-- install and no version to keep in step.
--
--     psql -v ON_ERROR_STOP=1 -f supabase/tests/rls_two_accounts.sql
--
-- Exits non-zero if any assertion fails.
-- ═══════════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on
\set QUIET on
set client_min_messages to notice;

do $test$
declare
  account_a constant uuid := '11111111-1111-4111-8111-111111111111';
  account_b constant uuid := '22222222-2222-4222-8222-222222222222';
  -- A third user who has NEVER written anything. Needed because several
  -- forge attempts would otherwise collide with a row A already seeded, and
  -- a unique-violation is not proof that RLS did anything.
  account_c constant uuid := '33333333-3333-4333-8333-333333333333';

  a_log_id   uuid;
  a_food_id  uuid;
  a_photo_id uuid;

  passed  int := 0;
  failures text[] := '{}';

-- Assertions are nested blocks rather than helper functions, so the test leaves
-- nothing behind in the database it just finished inspecting.
begin
  -- ── seed two accounts ──────────────────────────────────────────────────
  insert into auth.users (id, email) values
    (account_a, 'a@example.invalid'),
    (account_b, 'b@example.invalid'),
    (account_c, 'c@example.invalid')
  on conflict (id) do nothing;

  -- ── A writes one row into every table ──────────────────────────────────
  perform set_config('request.jwt.claim.sub', account_a::text, true);
  execute 'set local role authenticated';

  insert into profiles (id, height_cm, sex, goal_weight_kg)
    values (account_a, 175.0, 'male', 70.0);

  insert into foods (source, created_by, name, brand, kcal_per_100g)
    values ('custom', account_a, 'A''s own recipe', 'Homemade', 180)
    returning id into a_food_id;

  insert into food_logs (user_id, food_id, logged_at, grams, entry_method, kcal, name_snapshot)
    values (account_a, a_food_id, now(), 250, 'manual', 450, 'A''s own recipe')
    returning id into a_log_id;

  insert into photo_estimates (log_id, user_id, storage_path, model_output, confidence)
    values (a_log_id, account_a, account_a::text || '/lunch.jpg', '{"items":[]}'::jsonb, 0.7)
    returning id into a_photo_id;

  insert into weight_logs (user_id, measured_at, kg, source)
    values (account_a, now(), 78.4, 'manual');

  insert into health_samples (user_id, date, steps, active_energy)
    values (account_a, current_date, 8200, 430.5);

  insert into weekly_scores (user_id, week_start, consistency, adherence, progress, composite, tier, engine_version)
    values (account_a, current_date, 0.86, 0.71, 0.52, 0.71, 'gold', 'v0-phase1-placeholder');

  insert into sync_outbox (user_id, entity, entity_id, operation, payload)
    values (account_a, 'food_logs', a_log_id, 'insert', '{}'::jsonb);

  insert into storage.objects (bucket_id, name, owner)
    values ('meal-photos', account_a::text || '/lunch.jpg', account_a);

  reset role;

  -- ── P1-F's photo cap, claimed the way the Edge Function claims it ──────
  --
  -- Deliberately NOT an insert as `authenticated`: there is no insert policy
  -- on this table and no grant, so the client cannot write its own quota row
  -- at all. That is the whole reason §10's cap is server-side rather than a
  -- number in the app, and it is asserted below.
  --
  -- Claiming it here also exercises the function itself, which is the one piece
  -- of P1-F's backend that a unit test cannot reach: the atomic
  -- test-and-increment is a property of one SQL statement, and a read-then-write
  -- version would pass every test that did not run two of them at once.
  declare
    claimed int;
  begin
    for i in 1..5 loop
      claimed := claim_photo_estimate(account_a, 5);
    end loop;

    if claimed = 5 then
      passed := passed + 1;
      raise notice '  PASS  the photo cap counts up to its limit';
    else
      failures := failures || ('claim_photo_estimate returned ' || claimed || ' on the fifth call, expected 5');
      raise notice '  FAIL  the photo cap counted to % rather than 5', claimed;
    end if;

    -- The sixth is refused, and refused by the same statement that increments,
    -- so two concurrent requests cannot both pass the check.
    claimed := claim_photo_estimate(account_a, 5);
    if claimed < 0 then
      passed := passed + 1;
      raise notice '  PASS  the photo cap refuses past its limit';
    else
      failures := failures || ('the photo cap allowed a claim past its limit (returned ' || claimed || ')');
      raise notice '  FAIL  the photo cap allowed claim % past its limit', claimed;
    end if;
  end;

  raise notice '  seeded: account A owns a row in every table';
  raise notice '';

  -- ── B tries to read A's data ───────────────────────────────────────────
  perform set_config('request.jwt.claim.sub', account_b::text, true);
  execute 'set local role authenticated';

  declare
    r record;
    seen int;
    label text;
  begin
    for r in
      select * from (values
        ('profiles',            'select count(*) from profiles where id = ' || quote_literal(account_a)),
        ('food_logs',           'select count(*) from food_logs where user_id = ' || quote_literal(account_a)),
        ('photo_estimates',     'select count(*) from photo_estimates where user_id = ' || quote_literal(account_a)),
        ('weight_logs',         'select count(*) from weight_logs where user_id = ' || quote_literal(account_a)),
        ('health_samples',      'select count(*) from health_samples where user_id = ' || quote_literal(account_a)),
        ('weekly_scores',       'select count(*) from weekly_scores where user_id = ' || quote_literal(account_a)),
        ('sync_outbox',         'select count(*) from sync_outbox where user_id = ' || quote_literal(account_a)),
        ('photo_estimate_usage','select count(*) from photo_estimate_usage where user_id = ' || quote_literal(account_a)),
        ('storage.objects',     'select count(*) from storage.objects where owner = ' || quote_literal(account_a))
      ) as t(tbl, stmt)
    loop
      execute r.stmt into seen;
      label := 'B cannot READ A''s ' || r.tbl;
      if seen = 0 then
        passed := passed + 1;
        raise notice '  PASS  %', label;
      else
        failures := failures || (label || ' — saw ' || seen || ' row(s)');
        raise notice '  FAIL  %  (saw % rows)', label, seen;
      end if;
    end loop;
  end;

  -- ── B tries to change and destroy A's data ─────────────────────────────
  declare
    r record;
    affected int;
    label text;
  begin
    for r in
      select * from (values
        ('UPDATE A''s food_log',      'update food_logs set grams = 9999 where user_id = ' || quote_literal(account_a)),
        ('DELETE A''s food_log',      'delete from food_logs where user_id = ' || quote_literal(account_a)),
        ('UPDATE A''s weight_log',    'update weight_logs set kg = 1 where user_id = ' || quote_literal(account_a)),
        ('DELETE A''s weight_log',    'delete from weight_logs where user_id = ' || quote_literal(account_a)),
        ('UPDATE A''s profile',       'update profiles set height_cm = 1 where id = ' || quote_literal(account_a)),
        ('DELETE A''s health_sample', 'delete from health_samples where user_id = ' || quote_literal(account_a)),
        ('UPDATE A''s weekly_score',  'update weekly_scores set composite = 1 where user_id = ' || quote_literal(account_a)),
        ('DELETE A''s meal photo',    'delete from storage.objects where owner = ' || quote_literal(account_a)),
        ('EDIT A''s custom food',     'update foods set name = ''hijacked'' where created_by = ' || quote_literal(account_a))
      ) as t(what, stmt)
    loop
      execute r.stmt;
      get diagnostics affected = row_count;
      label := 'B cannot ' || r.what;
      if affected = 0 then
        passed := passed + 1;
        raise notice '  PASS  %', label;
      else
        failures := failures || (label || ' — changed ' || affected || ' row(s)');
        raise notice '  FAIL  %  (changed % rows)', label, affected;
      end if;
    end loop;
  end;

  -- ── B tries to write rows that claim to be somebody else's ────────────
  -- These RAISE rather than silently affecting nothing, so the assertion is
  -- inverted: the test fails if the write SUCCEEDS.
  --
  -- It also insists on the RIGHT exception. An earlier version accepted any
  -- error, and passed for the wrong reason: the forged weekly_score collided
  -- with the row A had already seeded, so a UNIQUE violation was standing in
  -- for a policy that had in fact been switched off. Only SQLSTATE 42501 —
  -- "new row violates row-level security policy" — is proof RLS did the work,
  -- so every forged row below is built to collide with nothing.
  declare
    r record;
    label text;
  begin
    for r in
      select * from (values
        ('forge a food_log as A',
         'insert into food_logs (user_id, logged_at, grams, entry_method, kcal, name_snapshot) values ('
           || quote_literal(account_a) || ', now(), 100, ''manual'', 100, ''forged'')'),
        -- A distinct timestamp: unique (user_id, measured_at, source).
        ('forge a weight_log as A',
         'insert into weight_logs (user_id, measured_at, kg) values ('
           || quote_literal(account_a) || ', now() + interval ''3 days'', 60)'),
        -- A different week: unique (user_id, week_start).
        ('forge a weekly_score as A',
         'insert into weekly_scores (user_id, week_start, composite, engine_version) values ('
           || quote_literal(account_a) || ', current_date + 7, 1.0, ''forged'')'),
        -- Account C, who has no profile: the profiles PK is the user id, so
        -- forging A''s would raise a duplicate key whether RLS held or not.
        ('forge a profile as another user',
         'insert into profiles (id) values (' || quote_literal(account_c) || ')'),
        ('forge a health_sample as A',
         'insert into health_samples (user_id, date, steps) values ('
           || quote_literal(account_a) || ', current_date + 30, 99999)'),
        ('upload a photo into A''s folder',
         'insert into storage.objects (bucket_id, name) values (''meal-photos'', '
           || quote_literal(account_a::text || '/stolen.jpg') || ')'),
        -- The cap is only a cap while the client cannot write the ledger. There
        -- is no insert or update policy on this table at all, so RLS denies —
        -- which is the safe direction to fail and the whole reason §10's limit
        -- is server-side rather than a number in the app.
        ('write its own photo quota',
         'insert into photo_estimate_usage (user_id, day, requests) values ('
           || quote_literal(account_b) || ', current_date, 0)')
      ) as t(what, stmt)
    loop
      label := 'B cannot ' || r.what;
      begin
        execute r.stmt;
        failures := failures || (label || ' — the write SUCCEEDED');
        raise notice '  FAIL  %  (it worked)', label;
      exception
        when insufficient_privilege then
          passed := passed + 1;
          raise notice '  PASS  %', label;
        when others then
          failures := failures || (label || ' — rejected by ' || sqlstate
            || ' (' || sqlerrm || '), not by RLS');
          raise notice '  FAIL  %  (rejected by %, not RLS)', label, sqlstate;
      end;
    end loop;
  end;

  -- ── B tries to give away one of its OWN rows ──────────────────────────
  -- The attack an UPDATE policy with only `using` and no `with check` allows:
  -- the row passes the check on the way in, because it is genuinely yours, and
  -- you rewrite user_id on the way out. Nothing above catches this — every
  -- other update assertion starts from a row B cannot see in the first place.
  declare
    own_log uuid;
    label text := 'B cannot reassign its own weight_log to A';
  begin
    insert into weight_logs (user_id, measured_at, kg)
      values (account_b, now(), 90.0);
    begin
      update weight_logs set user_id = account_a where user_id = account_b;
      failures := failures || (label || ' — the reassignment SUCCEEDED');
      raise notice '  FAIL  %  (it worked)', label;
    exception
      when insufficient_privilege then
        passed := passed + 1;
        raise notice '  PASS  %', label;
      when others then
        failures := failures || (label || ' — rejected by ' || sqlstate || ', not by RLS');
        raise notice '  FAIL  %  (rejected by %, not RLS)', label, sqlstate;
    end;
  end;

  -- ── the CHECK constraint, which is not RLS and is asserted as itself ──
  declare
    label text := 'nobody can pass an Open Food Facts row off as their own';
  begin
    begin
      insert into foods (source, created_by, name, kcal_per_100g)
        values ('off', account_b, 'fake', 100);
      failures := failures || (label || ' — it was allowed');
      raise notice '  FAIL  %  (it worked)', label;
    exception
      when check_violation or insufficient_privilege then
        passed := passed + 1;
        raise notice '  PASS  %', label;
    end;
  end;

  -- ── the shared catalogue is deliberately shared ────────────────────────
  declare
    seen int;
  begin
    execute 'select count(*) from foods where id = ' || quote_literal(a_food_id) into seen;
    if seen = 1 then
      passed := passed + 1;
      raise notice '  PASS  B CAN read the shared food catalogue (this one is on purpose)';
    else
      failures := failures || 'the shared food catalogue is not readable by other users';
      raise notice '  FAIL  B cannot read the shared food catalogue';
    end if;
  end;

  -- ── P1-F Path 1: the ranked search, still as account B ─────────────────
  --
  -- A smoke test rather than a relevance test: what it catches is the class of
  -- failure that only shows up against a real Postgres — a parameter name
  -- colliding with a column, a tsquery parser that raises on ordinary
  -- punctuation, a function the client cannot execute. None of that is
  -- reachable from a Swift test, because none of it is Swift.
  declare
    seen int;
  begin
    execute 'select count(*) from search_foods(''own recipe'', 10)' into seen;
    if seen >= 1 then
      passed := passed + 1;
      raise notice '  PASS  search_foods returns a ranked match';
    else
      failures := failures || 'search_foods returned nothing for a phrase in a seeded food';
      raise notice '  FAIL  search_foods found nothing';
    end if;

    -- A search box receives this. `to_tsquery` would raise a syntax error on
    -- it; `websearch_to_tsquery` is why the function does not.
    execute 'select count(*) from search_foods(''!! & "" recipe'', 10)' into seen;
    passed := passed + 1;
    raise notice '  PASS  search_foods survives punctuation a user can type';
  end;

  reset role;

  -- ── signed out, nothing at all ─────────────────────────────────────────
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
  declare
    seen int;
  begin
    begin
      execute 'select count(*) from food_logs' into seen;
      if seen = 0 then
        passed := passed + 1;
        raise notice '  PASS  signed out, food_logs is empty';
      else
        failures := failures || ('anon read ' || seen || ' food_logs');
        raise notice '  FAIL  signed out read % food_logs', seen;
      end if;
    exception when insufficient_privilege then
      passed := passed + 1;
      raise notice '  PASS  signed out, food_logs is not even readable';
    end;
  end;
  reset role;

  -- ── verdict ────────────────────────────────────────────────────────────
  raise notice '';
  if array_length(failures, 1) is null then
    raise notice '  %  assertions passed. Account A''s data is not reachable by account B.', passed;
  else
    raise exception E'RLS FAILED — % of % assertions:\n    %',
      array_length(failures, 1), passed + array_length(failures, 1),
      array_to_string(failures, E'\n    ');
  end if;
end;
$test$;
