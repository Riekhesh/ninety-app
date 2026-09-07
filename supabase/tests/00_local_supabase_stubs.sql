-- ═══════════════════════════════════════════════════════════════════════════
-- LOCAL TEST HARNESS ONLY — never applied to a Supabase project.
--
-- Supabase provides `auth.users`, `auth.uid()`, `storage.objects` and the
-- `anon` / `authenticated` roles. Vanilla Postgres does not, so the migrations
-- cannot be applied — or the RLS tested — without standing them up first.
--
-- These are the smallest stubs that make the real migrations run unmodified.
-- The migrations are what ships; nothing in this file does. It lives under
-- tests/ and is applied only by scripts/verify-rls.sh, so it cannot reach
-- `supabase db push`, which reads migrations/ alone.
-- ═══════════════════════════════════════════════════════════════════════════

create schema if not exists auth;
create schema if not exists storage;

create table if not exists auth.users (
  id    uuid primary key,
  email text unique
);

-- Supabase derives auth.uid() from the JWT the request carried. Locally the
-- test sets that claim directly, which is exactly how Supabase's own local
-- development flow does it.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon');
$$;

-- storage.objects, cut down to the columns the photo policies actually use.
create table if not exists storage.objects (
  id       uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name     text not null,
  owner    uuid,
  created_at timestamptz not null default now()
);

create table if not exists storage.buckets (
  id     text primary key,
  name   text not null,
  public boolean not null default false
);

-- Splits an object name into path segments. The photo policies key on the
-- first segment being the owner's uuid, which is Supabase's documented pattern.
create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select string_to_array(name, '/');
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end;
$$;

grant usage on schema public, auth, storage to anon, authenticated;

-- Supabase already grants these on its own storage tables, and a user
-- migration cannot: storage.objects is owned by supabase_storage_admin, not by
-- the role that runs migrations. So the grant belongs here, with the rest of
-- what Supabase provides, rather than in 002 where it would fail on a real
-- project. The POLICIES on storage.objects are ours and do live in 002.
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
