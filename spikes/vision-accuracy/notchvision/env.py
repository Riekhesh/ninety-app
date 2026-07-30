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

__all__ = [
    "describe_missing",
    "find_dotenv",
    "find_near_misses",
    "load_dotenv",
    "parse_dotenv",
]


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


def find_dotenv(start: Path) -> Path | None:
    """Walk up from `start` looking for a `.env`.

    The spike lives two directories below the repo root, where `.env` is. Walking up
    means the file is found whether you run from the spike directory or the repo root.
    """
    for directory in (start, *start.parents):
        candidate = directory / ".env"
        if candidate.is_file():
            return candidate
    return None


def find_near_misses(start: Path) -> list[Path]:
    """Files that were probably meant to be `.env`.

    macOS Finder hides known extensions, so a file created in TextEdit or via
    "New Document" lands as `.env.txt` while displaying as `.env`. That is
    indistinguishable from the file being absent, and "no .env found" is a
    maddening thing to read when you can see the file in Finder.

    `.env.example` is excluded — it always exists, so reporting it is noise.
    """
    misses: list[Path] = []
    for directory in (start, *start.parents):
        try:
            entries = list(directory.iterdir())
        except OSError:
            continue
        for entry in entries:
            name = entry.name.lower()
            if name in (".env", ".env.example") or not entry.is_file():
                continue
            if name.startswith(".env") or name in ("env", "env.txt"):
                misses.append(entry)
    return misses


def describe_missing(start: Path) -> str:
    """Explain a missing `.env` in terms of what is actually on disk."""
    lines = ["· env: no .env found (searched upward from the spike directory)"]

    for miss in find_near_misses(start)[:3]:
        lines.append(f"    found {miss} — did you mean this to be .env?")
        if miss.name.lower().endswith((".txt", ".rtf")):
            lines.append("    macOS hides known extensions, so this shows as '.env' in Finder.")
            lines.append(f"    fix: mv '{miss}' '{miss.with_name('.env')}'")

    # Where the file belongs, stated as a path rather than left as an exercise.
    for directory in (start, *start.parents):
        if (directory / ".env.example").is_file():
            lines.append(f"    expected: {directory / '.env'}")
            break

    return "\n".join(lines)


def load_dotenv(start: Path | None = None) -> Path | None:
    """Load the nearest `.env` into `os.environ`. Returns the file used, or None.

    **A real environment variable always wins.** An exported `GEMINI_API_KEY` is a
    deliberate per-run override, and CI sets keys as secrets rather than files — so a
    stale value in `.env` must never silently replace either. Empty values in `.env`
    are ignored too, since `.env.example` ships every key blank and a blank key would
    otherwise read as "set" and fail at the API instead of at startup.
    """
    path = find_dotenv(start or Path.cwd())
    if path is None:
        return None
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    for key, value in parse_dotenv(text).items():
        if value and not os.environ.get(key):
            os.environ[key] = value
    return path
