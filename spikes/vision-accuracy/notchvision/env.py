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

__all__ = ["find_dotenv", "load_dotenv", "parse_dotenv"]


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
