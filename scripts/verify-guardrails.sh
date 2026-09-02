#!/usr/bin/env bash
# Prove the guardrails actually fire.
#
# The repo has three layers of enforcement that are all easy to *believe* in and
# nobody had ever confirmed:
#
#   1. .githooks/pre-commit   — secret and health-data tripwires
#   2. .githooks/commit-msg   — Conventional Commits
#   3. .swiftlint.yml         — engine purity, token colours, S5 copy ban
#
# A control nobody has tested is a control you are trusting, not one you have.
# This runs each of them against a deliberate violation and fails if the
# violation gets through.
#
#     scripts/verify-guardrails.sh
#
# The hook checks run anywhere. The SwiftLint checks need swiftlint installed
# and are skipped, loudly, when it is not.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

pass=0
fail=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$1"; fail=$((fail + 1)); }
skip() { printf '  \033[33m·\033[0m %s\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ─── 1 & 2. The git hooks ────────────────────────────────────────────────────
# Run in a throwaway repo. Pointing the real one at deliberately bad commits is
# how you end up with a deliberately bad commit.

head_ "Git hooks"

REPO="$SCRATCH/repo"
mkdir -p "$REPO"
git -C "$REPO" init --quiet
git -C "$REPO" config user.email "guardrails@example.invalid"
git -C "$REPO" config user.name "Guardrail Check"
cp -R "$ROOT/.githooks" "$REPO/.githooks"
git -C "$REPO" config core.hooksPath .githooks
mkdir -p "$REPO/spikes/vision-accuracy/photos"

# `expect_block <description> <"reject"|"accept"> <path> <content> <message>`
expect_block() {
  local what="$1" want="$2" path="$3" content="$4" message="$5"
  mkdir -p "$REPO/$(dirname "$path")"
  printf '%s\n' "$content" > "$REPO/$path"
  git -C "$REPO" add --force "$path" >/dev/null 2>&1

  if git -C "$REPO" commit -m "$message" >/dev/null 2>&1; then
    got="accept"
  else
    got="reject"
  fi

  if [ "$got" = "$want" ]; then
    ok "$what"
  else
    bad "$what — hook said '$got', expected '$want'"
  fi

  git -C "$REPO" reset --quiet HEAD -- "$path" 2>/dev/null || true
  rm -f "$REPO/$path"
}

# A structurally valid Anthropic-shaped key. Fake, and never a real
# prefix+body pair that could be mistaken for one in a scan.
#
# Assembled from two adjacent literals rather than written out whole. The
# tripwire this line exists to test matches `sk-ant-api\d\d-` contiguously, so
# a literal here would — correctly — block this very file from being committed.
# Adding the file to the hook's exclusion list was the other option; this keeps
# the tripwire strict everywhere instead of carving out the one file whose job
# is to prove it works.
FAKE_KEY="sk-ant-""api03-$(printf 'A%.0s' {1..24})"

expect_block "a secret in a staged file is blocked" reject \
  "Sources/Leak.swift" "let key = \"$FAKE_KEY\"" "feat(auth): add a key"

expect_block "a meal photo is blocked (Article 9)" reject \
  "spikes/vision-accuracy/photos/lunch.jpg" "not-really-a-jpeg" "spike(photo): add a meal photo"

expect_block "a non-conventional commit subject is rejected" reject \
  "docs/note.md" "hello" "Added some stuff."

expect_block "a conventional commit with clean content is accepted" accept \
  "docs/note.md" "hello" "docs(repo): add a note"

# ─── 3. The SwiftLint custom rules ───────────────────────────────────────────

head_ "SwiftLint custom rules"

if ! command -v swiftlint >/dev/null 2>&1; then
  skip "swiftlint not installed — brew install swiftlint. Rules unverified."
  skip "CI runs these on macOS; this half is skipped here, not passed."
else
  LINT="$SCRATCH/lint"
  # The engine rules key off the path, so the fixture has to live at the path
  # the `included:` regex matches.
  mkdir -p "$LINT/Packages/RankingEngine/Sources/RankingEngine" "$LINT/Ninety"
  cp "$ROOT/.swiftlint.yml" "$LINT/.swiftlint.yml"

  cat > "$LINT/Packages/RankingEngine/Sources/RankingEngine/Impure.swift" <<'SWIFT'
import SwiftUI

enum Impure {
    static func score() -> Double {
        let now = Date()
        _ = now
        return Double.random(in: 0...1)
    }
}
SWIFT

  cat > "$LINT/Ninety/Bad.swift" <<'SWIFT'
import SwiftUI

struct Bad: View {
    var body: some View {
        Text("You missed 3 days")
            .foregroundStyle(Color(red: 1, green: 0, blue: 0))
            .cornerRadius(12)
    }
}
SWIFT

  report="$(cd "$LINT" && swiftlint lint --quiet --reporter csv 2>/dev/null)"

  # `expect_rule <rule id> <what it protects>`
  expect_rule() {
    if printf '%s' "$report" | grep -q "$1"; then
      ok "$2 ($1)"
    else
      bad "$2 — rule '$1' did not fire on a deliberate violation"
    fi
  }

  expect_rule ranking_engine_no_ui_imports   "the engine cannot import SwiftUI"
  expect_rule ranking_engine_no_ambient_clock "the engine cannot read the clock"
  expect_rule ranking_engine_no_randomness    "the engine cannot be random"
  expect_rule no_punishment_framing           "S5: punishment framing fails the build"
  expect_rule no_hardcoded_colour             "colours must come from tokens"
  expect_rule no_magic_corner_radius          "radii must come from the scale"

  # And the real tree must be clean, or --strict fails the PR.
  if (cd "$ROOT" && swiftlint lint --quiet --strict >/dev/null 2>&1); then
    ok "the committed tree is clean under --strict"
  else
    bad "the committed tree has SwiftLint violations under --strict"
  fi
fi

# ─── 4. The app bundle's own plist ───────────────────────────────────────────
# Xcode injects six CFBundle keys when it generates the plist, and stops the
# moment you supply one. The app then builds cleanly and fails at install with
# "Missing bundle ID" — a message that names the symptom, not the cause. This
# is the cheap check that catches it before a Mac ever sees the build.

head_ "App bundle"

while IFS= read -r line; do
  case "$line" in
    "OK "*)  ok "${line#OK }" ;;
    "BAD "*) bad "${line#BAD }" ;;
  esac
done < <(python3 "$ROOT/scripts/check_bundle.py" "$ROOT")

head_ "Result"
printf '  %d passed, %d failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
