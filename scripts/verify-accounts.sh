#!/usr/bin/env bash
#
# Verify the Phase 0 service accounts (§0.2).
#
#   scripts/verify-accounts.sh
#
# Turns "create a Supabase and a PostHog project" from a ticked checkbox into a
# testable condition (§00 rule 2). Reads .env, checks each value is present and
# the right shape, and NEVER prints a key. Click-path: docs/phase-0/accounts.md
#
# Exits non-zero if a required value is missing or malformed.

set -uo pipefail

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=1; }
info() { printf '    \033[2m%s\033[0m\n' "$1"; }

FAILED=0
printf '\n\033[1mNinety — Phase 0 accounts check\033[0m\n\n'

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
env_file="$repo_root/.env"

if [ ! -f "$env_file" ]; then
  bad ".env not found — cp .env.example .env, then fill it in"
  info "docs/phase-0/accounts.md has the click-path for every value"
  exit 1
fi

# The whole file is about to be read into memory. If it is not ignored, nothing
# else here matters.
if git -C "$repo_root" check-ignore -q .env 2>/dev/null; then
  ok ".env is gitignored"
else
  bad ".env is NOT gitignored — fix this before anything else"
  info "every value below is a secret; a commit means rotating all of them"
  exit 1
fi

# Read values without sourcing the file — .env is data, not shell, and a stray
# backtick in a generated password should not execute.
val() {
  sed -n "s/^[[:space:]]*$1=//p" "$env_file" | tail -1 | tr -d '\r' \
    | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# check NAME "human label" [regex]
check() {
  local name="$1" label="$2" pattern="${3:-}" v
  v=$(val "$name")
  if [ -z "$v" ]; then
    bad "$name is blank — $label"
    return
  fi
  if [ -n "$pattern" ] && ! printf '%s' "$v" | grep -qE "$pattern"; then
    bad "$name is set but does not look right — $label"
    info "expected to match: $pattern"
    return
  fi
  ok "$name set (${#v} chars)"
}

# ── Supabase ────────────────────────────────────────────────────────────────
printf '\033[1m  Supabase\033[0m\n'
check SUPABASE_URL "the project URL from Project Settings → API" \
      '^https://[a-z0-9-]+\.supabase\.(co|in)/?$'
check SUPABASE_ANON_KEY "public by design; RLS is what protects the data"
check SUPABASE_SERVICE_ROLE_KEY "bypasses RLS — treat as a root password"
check SUPABASE_DB_PASSWORD "needed for migrations; not retrievable from the dashboard"

anon=$(val SUPABASE_ANON_KEY)
service=$(val SUPABASE_SERVICE_ROLE_KEY)
if [ -n "$anon" ] && [ "$anon" = "$service" ]; then
  bad "anon and service_role keys are identical — one of them is pasted wrong"
  info "the service_role key bypasses RLS; shipping it as the anon key would expose everything"
fi

# ── PostHog ─────────────────────────────────────────────────────────────────
printf '\n\033[1m  PostHog\033[0m\n'
check POSTHOG_PROJECT_API_KEY "write-only ingest key from Project Settings" '^phc_'

host=$(val POSTHOG_HOST)
case "$host" in
  https://eu.i.posthog.com*) ok "POSTHOG_HOST is the EU cloud" ;;
  "")   bad "POSTHOG_HOST is blank — expected https://eu.i.posthog.com" ;;
  *eu*) warn "POSTHOG_HOST is '$host' — EU-ish, but not the documented endpoint" ;;
  *)    bad "POSTHOG_HOST is '$host' — not the EU cloud"
        info "UK GDPR Article 9 health data. Region is fixed at signup; a US project needs recreating." ;;
esac

# ── Gemini, already done — checked so this script covers the whole .env ──────
printf '\n\033[1m  Vision (already done)\033[0m\n'
if [ -n "$(val GEMINI_API_KEY)" ]; then
  ok "GEMINI_API_KEY set"
else
  warn "GEMINI_API_KEY blank — Spike B cannot run (ADR 0010)"
fi

# ── What a script cannot see ────────────────────────────────────────────────
printf '\n\033[1mConfirm these by eye — one-way doors\033[0m\n'
printf '  \033[2m·\033[0m Supabase region is EU/London. Fixed at creation; changing it means\n'
printf '    a dump, a new project, and reissuing every key above.\n'
printf '  \033[2m·\033[0m PostHog session replay is OFF. It records the screen, and on this app\n'
printf '    the screen is someone'"'"'s weight and food.\n'
printf '  \033[2m·\033[0m PostHog autocapture is OFF. It captures element text, which on a food\n'
printf '    log is the food.\n'
printf '  \033[2m·\033[0m GitHub secret scanning WITH push protection is on for this repo.\n'
printf '  \033[2m·\033[0m No tables created yet — Phase 1 creates them as migrations with RLS.\n\n'

if [ "$FAILED" -ne 0 ]; then
  printf '\033[31mSome values are missing or malformed — see ✗ above.\033[0m\n'
  printf 'Click-path for each: \033[2mdocs/phase-0/accounts.md\033[0m\n\n'
  exit 1
fi
printf '\033[32mAccounts look good.\033[0m\n\n'
