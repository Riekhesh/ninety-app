#!/usr/bin/env bash
# Prove the RLS policies hold, against a real Postgres.
#
#     scripts/verify-rls.sh
#
# Boots a throwaway cluster, applies the migrations exactly as `supabase db
# push` would, and runs the two-account proof. Nothing touches your Supabase
# project, and nothing is left running.
#
# Phase 1's exit criterion is "RLS policies on every table, tested with two
# accounts", and docs/security/secrets.md is blunt about the standard: "assume
# it is broken until you have seen it fail." This is the seeing.
#
# Needs a Postgres SERVER, not just psql:
#     macOS   brew install postgresql@16
#     Ubuntu  apt-get install -y postgresql-16
#
# `supabase start` is the other way to get one, and works too — point PGHOST,
# PGPORT and PGUSER at it and this script will use it instead of booting its own.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

say()  { printf '\033[2m  %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
bad()  { printf '\033[31m  ✗ %s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

OWN_CLUSTER=0
PGDATA_DIR="$(mktemp -d)/pgdata"

cleanup() {
  if [ "$OWN_CLUSTER" = "1" ]; then
    "$PGBIN/pg_ctl" -D "$PGDATA_DIR" stop -m immediate >/dev/null 2>&1 || true
    rm -rf "$(dirname "$PGDATA_DIR")"
  fi
}
trap cleanup EXIT

head_ "Postgres"

# Prefer a server the caller already has (supabase start, a local install).
if [ -n "${PGHOST:-}" ] && psql -tAc 'select 1' postgres >/dev/null 2>&1; then
  ok "using the Postgres already at ${PGHOST}:${PGPORT:-5432}"
else
  PGBIN=""
  for candidate in \
    "$(pg_config --bindir 2>/dev/null || true)" \
    /usr/lib/postgresql/*/bin \
    /opt/homebrew/opt/postgresql@16/bin \
    /usr/local/opt/postgresql@16/bin
  do
    if [ -n "$candidate" ] && [ -x "$candidate/initdb" ]; then PGBIN="$candidate"; break; fi
  done

  if [ -z "$PGBIN" ]; then
    bad "no Postgres server found (initdb is not on this machine)"
    say "macOS:  brew install postgresql@16"
    say "Ubuntu: apt-get install -y postgresql-16"
    say "or run 'supabase start' and re-run this with PGHOST/PGPORT set"
    exit 1
  fi

  export PGHOST=/tmp PGPORT=${PGPORT:-54329} PGUSER=postgres
  mkdir -p "$PGDATA_DIR"

  # initdb refuses to run as root, which is exactly the case in CI containers.
  RUNAS=""
  if [ "$(id -u)" = "0" ] && id postgres >/dev/null 2>&1; then
    RUNAS="postgres"
    chown -R postgres "$(dirname "$PGDATA_DIR")"
    chmod 1777 /tmp
  fi

  run() { if [ -n "$RUNAS" ]; then su "$RUNAS" -c "$1"; else bash -c "$1"; fi; }

  run "'$PGBIN/initdb' -D '$PGDATA_DIR' -U postgres --auth=trust" >/dev/null 2>&1
  run "'$PGBIN/pg_ctl' -D '$PGDATA_DIR' -o '-k /tmp -p $PGPORT -c listen_addresses=' -w start" >/dev/null 2>&1
  OWN_CLUSTER=1
  ok "booted a throwaway cluster on port $PGPORT"
fi

DB=ninety_rls_check
psql -q -c "drop database if exists $DB;" -c "create database $DB;" postgres >/dev/null

head_ "Migrations"

# The stubs stand in for auth.users, auth.uid() and storage.objects, which
# Supabase provides and vanilla Postgres does not. They live under tests/ so
# `supabase db push` — which reads migrations/ only — can never apply them.
psql -q -d "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/00_local_supabase_stubs.sql
say "local Supabase stubs applied (auth, storage, roles)"

for migration in supabase/migrations/*.sql; do
  psql -q -d "$DB" -v ON_ERROR_STOP=1 -f "$migration"
  ok "$(basename "$migration")"
done

# Supabase enables RLS on storage.objects itself; the stub table does not.
psql -q -d "$DB" -c "alter table storage.objects enable row level security;" >/dev/null

head_ "Every table has RLS on, and at least one policy"

missing="$(psql -d "$DB" -tA -F' ' -c "
  select c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policy p where p.polrelid = c.oid))
  order by c.relname;")"

if [ -n "$missing" ]; then
  bad "tables with RLS off or no policy at all:"
  printf '      %s\n' $missing
  exit 1
fi
ok "$(psql -d "$DB" -tAc "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r';") tables, all with RLS enabled and policies defined"

head_ "Two accounts"
psql -q -d "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/rls_two_accounts.sql 2>&1 \
  | sed 's/^psql:[^ ]*: //; s/^NOTICE:  //'

head_ "Result"
printf '  RLS verified against PostgreSQL %s\n\n' \
  "$(psql -d "$DB" -tAc 'show server_version')"
