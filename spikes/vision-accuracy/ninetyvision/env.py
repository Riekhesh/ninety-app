"""Load `.env` into the process environment.

The harness reads its keys from `os.environ`, but the key actually lives in the
repo-root `.env` that `.env.example` tells you to create. Without this module
nothing bridges the two: you copy the template, fill in the key, re-run, and get
the identical "GEMINI_API_KEY is not set" error with no indication why.

Deliberately stdlib-only. `requirements.txt` calls itself minimal because "every
dependency is one more thing that can break a run you only get to do once", and
that argument applies hardest to the twenty lines that read a key=value file.
"""

from __future__ import annotations

import os
from pathlib import Path

__all__ = ["find_all_dotenv", "find_dotenv", "load_dotenv", "parse_dotenv"]


def parse_dotenv(text: str) -> dict[str, str]:
    """Parse `.env` text into a mapping.

    Handles what `.env.example` actually contains — comments, blank lines, box-drawing
    section headers — plus the two conventions people reach for without thinking:
    a leading `export`, and quoted values.
    """
    out: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].lstrip()
        key, sep, value = line.partition("=")
        if not sep:
            continue
        key = key.strip()
        if not key or not key.replace("_", "").isalnum():
            # Not an assignment — a box-drawing rule or prose. Skip it silently.
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        out[key] = value
    return out


def find_all_dotenv(start: Path) -> list[Path]:
    """Every `.env` on the search path, nearest first.

    Only the first is ever loaded. This exists so `load_dotenv` can *say* when there
    is more than one, because the alternative is silent: a second `.env` in the spike
    directory shadows the repo-root one completely, and the symptom is a key or a
    model id that is definitely in a file having no effect at all.
    """
    found: list[Path] = []
    for directory in (start, *start.parents):
        candidate = directory / ".env"
        if candidate.is_file():
            found.append(candidate)
    return found


def find_dotenv(start: Path) -> Path | None:
    """The nearest `.env` walking up from `start`, or None.

    The spike lives two directories below the repo root, where `.env` is. Walking up
    means the file is found whether you run from the spike directory or the repo root.
    """
    found = find_all_dotenv(start)
    return found[0] if found else None


def load_dotenv(start: Path | None = None) -> Path | None:
    """Load the nearest `.env` into `os.environ`. Returns the file used, or None.

    **A real environment variable always wins.** An exported `GEMINI_API_KEY` is a
    deliberate per-run override, and CI sets keys as secrets rather than files — so a
    stale value in `.env` must never silently replace either. Empty values in `.env`
    are ignored too, since `.env.example` ships every key blank and a blank key would
    otherwise read as "set" and fail at the API instead of at startup.
    """
    candidates = find_all_dotenv(start or Path.cwd())
    if not candidates:
        return None
    path = candidates[0]
    if len(candidates) > 1:
        # Nearest wins and the rest are never opened. Never guess which the user
        # meant — say plainly that the others are inert, so a key that is "definitely
        # in the file" has a visible reason for not being seen.
        import sys

        print(f"! {len(candidates)} .env files on the search path. Using the nearest:",
              file=sys.stderr)
        for i, candidate in enumerate(candidates):
            note = "  <- loaded" if i == 0 else "  <- IGNORED, entirely"
            print(f"    {candidate}{note}", file=sys.stderr)
        print("  Keep one, at the repo root. See docs/security/secrets.md.",
              file=sys.stderr)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    for key, value in parse_dotenv(text).items():
        if value and not os.environ.get(key):
            os.environ[key] = value
    return path
