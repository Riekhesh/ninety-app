-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — check a REAL project matches what the local proof asserts.
--
-- Read-only. Paste into the dashboard's SQL Editor and run, or:
--     psql "$(supabase db url)" -f supabase/tests/verify_remote.sql
--
-- scripts/verify-rls.sh proves the policies hold against a throwaway Postgres.
-- This is the other half: that the database your app will actually talk to came
-- out the same way. The two can differ — a hosted project has default
-- privileges, extensions and an existing storage schema that a fresh cluster
-- does not, and every one of those is a chance for a migration to land
-- differently than it did locally.
--
-- Every row should read OK. Anything else is worth stopping for.
-- ═══════════════════════════════════════════════════════════════════════════

with tables as (
  select c.oid, c.relname, c.relrowsecurity,
         (select count(*) from pg_policy p where p.polrelid = c.oid) as policies
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
),
-- Anything the signed-out role can still reach. RLS would deny it anyway —
-- there is no anon policy — but a grant that only matters if a policy is wrong
-- is a grant worth not having, so migration 002 revokes them.
anon_grants as (
  select table_name, string_agg(distinct privilege_type, ', ' order by privilege_type) as still_granted
  from information_schema.role_table_grants
  where grantee = 'anon' and table_schema = 'public'
  group by table_name
)
select
  t.relname                                                as table_name,
  case when t.relrowsecurity then 'on' else 'OFF' end      as rls,
  t.policies,
  coalesce(g.still_granted, '—')                           as anon_can,
  case
    when not t.relrowsecurity          then 'FAIL — RLS is off, this table is public'
    when t.policies = 0                then 'FAIL — no policy, nothing can read or write it'
    when g.still_granted is not null   then 'CHECK — anon still holds a grant'
    else 'OK'
  end                                                      as verdict
from tables t
left join anon_grants g on g.table_name = t.relname
order by (case when not t.relrowsecurity or t.policies = 0 then 0 else 1 end), t.relname;

-- The ten tables, the meal-photos bucket, and its four policies.
select
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r')                       as tables_expected_10,
  (select count(*) from storage.buckets where id = 'meal-photos')          as bucket_expected_1,
  (select count(*) from storage.buckets where id = 'meal-photos' and public) as bucket_public_expected_0,
  (select count(*) from pg_policy p join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'storage' and c.relname = 'objects'
       and p.polname like 'meal_photos%')                                  as photo_policies_expected_4;
