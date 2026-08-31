#!/usr/bin/env bash
#
# Verify the Phase 0 toolchain (§0.1).
#
#   scripts/verify-toolchain.sh
#
# Checks what it can and tells you plainly what it cannot. Exits non-zero if a
# hard requirement is unmet, so it is usable in a setup script.

set -uo pipefail

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=1; }
info() { printf '    \033[2m%s\033[0m\n' "$1"; }

FAILED=0
printf '\n\033[1mNotch — Phase 0 toolchain check\033[0m\n\n'

# ── macOS ───────────────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Darwin" ]; then
  bad "not macOS — iOS development needs a Mac (§0.1)"
  info "this script only makes sense on your development machine"
  exit 1
fi

os=$(sw_vers -productVersion)
major=${os%%.*}
minor=$(printf '%s' "$os" | cut -d. -f2)
minor=${minor:-0}
if [ "$major" -gt 26 ] || { [ "$major" -eq 26 ] && [ "$minor" -ge 2 ]; }; then
  ok "macOS $os (Xcode 26.6 needs 26.2+)"
else
  bad "macOS $os — Xcode 26.6 requires macOS Tahoe 26.2 or later"
fi

if [ "$(uname -m)" = "arm64" ]; then
  ok "Apple Silicon"
else
  warn "Intel Mac — works, but §0.1 strongly prefers Apple Silicon"
fi

# ── Disk ────────────────────────────────────────────────────────────────────
# §0.1's ~40 GB is the budget to INSTALL Xcode. Once it is installed that space
# is already spent, and what is left to protect is build headroom — DerivedData,
# device support files, simulator runtimes. Holding a machine that has Xcode to
# the install figure reports a red that means nothing and trains you to ignore
# the whole check.
avail_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ -d /Applications/Xcode.app ]; then
  need_gb=25; need_why="build headroom — DerivedData, device support, simulator runtimes"
else
  need_gb=40; need_why="§0.1's budget to install Xcode and its simulators"
fi
if [ "${avail_gb:-0}" -ge "$need_gb" ]; then
  ok "${avail_gb} GB free (need ~${need_gb}: ${need_why})"
else
  bad "${avail_gb:-?} GB free — need ~${need_gb} GB for ${need_why}"
  info "a real constraint on a 256 GB machine; builds fail confusingly when this runs out"
fi

# ── Xcode ───────────────────────────────────────────────────────────────────
if command -v xcodebuild >/dev/null 2>&1; then
  xc=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
  xc_major=${xc%%.*}
  if [ "${xc_major:-0}" -ge 26 ]; then
    ok "Xcode $xc"
    if [ "${xc_major:-0}" -ge 27 ]; then
      warn "Xcode $xc is ahead of 26.6 — §04 says do not develop on a beta for a project you intend to ship"
    fi
  else
    bad "Xcode $xc — App Store requires builds made with Xcode 26+ against the iOS 26 SDK since 28 April 2026"
  fi

  if xcodebuild -showsdks 2>/dev/null | grep -q "iphoneos26"; then
    ok "iOS 26 SDK present"
  else
    warn "iOS 26 SDK not found in xcodebuild -showsdks"
  fi
else
  bad "xcodebuild not found — install Xcode from the App Store, then run: sudo xcode-select --install"
fi

# ── Device ──────────────────────────────────────────────────────────────────
# HealthKit does not meaningfully work in the Simulator (§0.1), so a physical
# device is a hard requirement rather than a nicety.
if command -v xcrun >/dev/null 2>&1; then
  devices=$(xcrun xctrace list devices 2>/dev/null \
            | sed -n '/^== Devices ==/,/^== /p' \
            | grep -iE 'iphone' | grep -v 'Simulator' | grep -v '^==' || true)
  if [ -n "$devices" ]; then
    ok "physical iPhone visible:"
    printf '%s\n' "$devices" | sed 's/^/      /'
  else
    warn "no physical iPhone detected — plug it in and unlock it"
    info "HealthKit does not meaningfully work in the Simulator; you cannot fake your way through Spike A"
  fi
fi

# ── CLI tools ───────────────────────────────────────────────────────────────
for tool in git swiftlint python3; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool $("$tool" --version 2>/dev/null | head -1 | tr -d '\n' | cut -c1-40)"
  elif [ "$tool" = "swiftlint" ]; then
    warn "swiftlint missing — brew install swiftlint (configured already, §0.6)"
  else
    bad "$tool missing"
  fi
done

# ── Repo setup ──────────────────────────────────────────────────────────────
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$repo_root" ]; then
  if [ "$(git config core.hooksPath || true)" = ".githooks" ]; then
    ok "git hooks enabled"
  else
    warn "git hooks not enabled — run: git config core.hooksPath .githooks"
  fi

  if [ -f "$repo_root/.env" ]; then
    if git -C "$repo_root" check-ignore -q .env; then
      ok ".env present and gitignored"
    else
      bad ".env is NOT gitignored — fix before committing anything"
    fi
  else
    warn ".env missing — cp .env.example .env (needed for Spike B)"
  fi

  if python3 "$repo_root/design/tokens/generate.py" --check >/dev/null 2>&1; then
    ok "design tokens valid and generated files in sync"
  else
    warn "design tokens stale or invalid — run: python3 design/tokens/generate.py"
  fi
fi

# ── Things this script cannot check ─────────────────────────────────────────
printf '\n\033[1mCheck these yourself\033[0m\n'
printf '  \033[2m·\033[0m Apple Developer Program membership is ACTIVE — the critical path.\n'
printf '    developer.apple.com/account. If "HealthKit" is missing from Xcode'"'"'s\n'
printf '    capability list, or the signing team dropdown is empty, it has not cleared.\n'
printf '  \033[2m·\033[0m Service accounts and keys: \033[2mscripts/verify-accounts.sh\033[0m checks those.\n'
printf '    (Supabase, PostHog, GEMINI_API_KEY, GitHub secret scanning.)\n\n'

if [ "$FAILED" -ne 0 ]; then
  printf '\033[31mSome hard requirements are unmet — see ✗ above.\033[0m\n\n'
  exit 1
fi
printf '\033[32mToolchain looks good.\033[0m\n\n'
