#!/usr/bin/env python3
"""Check the app bundle's Info.plist agrees with what is in the repo.

Prints `OK <what>` / `BAD <what>` lines for scripts/verify-guardrails.sh.

Exists because of a real failure: with GENERATE_INFOPLIST_FILE off, Xcode stops
injecting CFBundleIdentifier and five other standard keys, and an app missing
them compiles perfectly and then fails at install with "Missing bundle ID" —
which names the symptom rather than the cause. None of this needs a Mac to
check, so none of it should reach one unchecked.
"""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path

# Settings that must reach the bundle as a build-setting reference and never as
# a literal. Both name one person's Supabase project: neither is a secret
# (docs/security/secrets.md puts the project URL and the publishable key in the
# "ships in the bundle" row, because RLS is the security boundary), but this
# repository is read by other people, and the moment a real value is pasted in
# here it is committed. They live in the gitignored Config/Local.xcconfig, like
# DEVELOPMENT_TEAM.
SUBSTITUTED = {
    "NinetySupabaseHost": "SUPABASE_HOST",
    "NinetySupabaseAnonKey": "SUPABASE_ANON_KEY",
}

# The keys Xcode injects for you, and stops injecting the moment you supply
# your own plist. Plus the two version keys the App Store requires.
REQUIRED = [
    "CFBundleIdentifier",
    "CFBundleExecutable",
    "CFBundleName",
    "CFBundlePackageType",
    "CFBundleInfoDictionaryVersion",
    "CFBundleDevelopmentRegion",
    "CFBundleShortVersionString",
    "CFBundleVersion",
]


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    plist = root / "Config" / "Info.plist"
    fonts = root / "Ninety" / "Resources" / "Fonts"

    try:
        info = plistlib.loads(plist.read_bytes())
    except Exception as exc:  # noqa: BLE001 — any parse failure is equally fatal
        print(f"BAD Config/Info.plist does not parse: {exc}")
        return 0
    print("OK Config/Info.plist parses")

    missing = [key for key in REQUIRED if key not in info]
    if missing:
        print(f"BAD Info.plist is missing {', '.join(missing)} — the app will fail to install")
    else:
        print(f"OK all {len(REQUIRED)} standard CFBundle keys present")

    for key, setting in SUBSTITUTED.items():
        value = info.get(key)
        if value is None:
            print(f"BAD Info.plist is missing {key} — the app cannot find its Supabase project")
        elif value != f"$({setting})":
            # Deliberately does not print the value: if this has failed, the
            # value is the thing you do not want in a CI log either.
            print(f"BAD {key} holds a literal, not $({setting}) — that value is now committed")
        else:
            print(f"OK {key} is substituted from {setting}, not committed")

    declared = info.get("UIAppFonts", [])
    absent = [name for name in declared if not (fonts / name).exists()]
    if absent:
        print(f"BAD UIAppFonts names files not in the repo: {', '.join(absent)}")
    else:
        print(f"OK all {len(declared)} UIAppFonts files are in the repo")

    # The other direction: a face that ships but is not declared never
    # registers, and the text silently falls back to San Francisco.
    orphans = sorted({path.name for path in fonts.glob("*.ttf")} - set(declared))
    if orphans:
        print(f"BAD {', '.join(orphans)} ship in the bundle but are not in UIAppFonts")
    else:
        print("OK every bundled face is declared in UIAppFonts")

    return 0


if __name__ == "__main__":
    sys.exit(main())
