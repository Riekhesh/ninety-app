#!/usr/bin/env python3
"""Load Open Food Facts and USDA into `public.foods`.

    python3 scripts/import_food_mirror.py --off data/off.csv.gz --limit 200000
    python3 scripts/import_food_mirror.py --usda data/usda-foundation.json

P1-B deferred this to sit alongside P1-F, and the reasoning holds up: nothing in
the minimum daily-usable set needs it — manual entry is what starts the clock —
and the `foods` table has carried its `search_vector` column and GIN index since
migration 001, so this is a data job rather than a schema change.

**It is also the point at which P1-F's search and barcode routes stop being
theoretical.** *"Scan resolves against the mirrored Open Food Facts data"* is an
acceptance criterion with nothing behind it until this has run once.

---

## Getting the data

**Open Food Facts** publishes a full CSV export, ~10 GB uncompressed and mostly
columns this does not want:

    curl -LO https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz

**USDA FoodData Central** publishes JSON by dataset. "Foundation Foods" is the
small, high-quality one — a few thousand items with laboratory-measured values,
which is what makes it worth having next to a crowd-sourced catalogue:

    https://fdc.nal.usda.gov/download-datasets.html

Both are large, both are gitignored, and neither belongs in the repo.

---

## Why the filters are what they are

A food catalogue is only useful if the row you land on is right, and Open Food
Facts is crowd-sourced: it contains products with no energy value, products whose
energy is in the wrong unit, and products whose per-100 g figure would make them
denser than pure fat. Importing all of it produces a search that returns a
plausible wrong number, which is worse for this app than returning nothing — the
whole design principle is never to show a figure nobody measured.

So a row has to have a name, a barcode, and an energy value between 0 and 900
kcal per 100 g. Nine hundred is the ceiling because pure fat is about 900 and
nothing edible is denser; anything above it is a unit error.

---

## Running it

Needs `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the repo-root `.env`.
The service key bypasses RLS, which is exactly what a bulk import of rows that
belong to nobody requires — `foods_insert_own_custom` deliberately allows a
signed-in user to insert *only* their own custom foods.

`--dry-run` parses and reports without writing, and is the right way to check a
new export before pushing a quarter of a million rows at a database.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import sys
import urllib.parse
from pathlib import Path
from typing import Any, Iterator

ROOT = Path(__file__).resolve().parent.parent

# Above this, per 100 g, the figure is a unit error rather than a food: pure fat
# is about 900 kcal and nothing edible is denser.
MAX_KCAL_PER_100G = 900.0

# Rows per request. Large enough that 300,000 rows is a few hundred calls,
# small enough that one failure does not lose ten minutes of work.
BATCH = 1_000


class ImportError_(RuntimeError):
    pass


def load_env() -> tuple[str, str]:
    """The two values this needs, from the environment or the repo-root .env.

    The nearest .env wins and the walk stops there — the same rule CLAUDE.md
    records, because a merged environment is one nobody can reason about.
    """
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    env = ROOT / ".env"
    if env.exists() and not (url and key):
        for line in env.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, _, value = line.partition("=")
            name, value = name.strip(), value.strip().strip('"').strip("'")
            if name == "SUPABASE_URL" and not url:
                url = value
            elif name == "SUPABASE_SERVICE_ROLE_KEY" and not key:
                key = value

    if not url or not key:
        raise ImportError_(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are needed. Copy .env.example "
            "to .env and fill them in — the service key bypasses RLS, which is what a "
            "bulk import of rows belonging to nobody requires."
        )
    return project_url(url), key


def project_url(value: str) -> str:
    """Scheme, host, nothing else — whatever shape the value arrived in.

    The dashboard shows several URLs on one page and they are easy to mix up:
    the project URL, the REST endpoint (`.../rest/v1`), and the host on its own
    with no scheme. Pasting the second one produced
    `…supabase.co/rest/v1/rest/v1/foods` and a `ValueError` from deep inside
    `urllib` naming neither the setting nor the file it came from.

    So the value is normalised rather than trusted: the path is discarded, a
    missing scheme is added, and anything that is not an https host is refused
    here with a message that says which setting is wrong. `SupabaseConfiguration`
    on the Swift side already does the same job for the same reason — a URL is
    one of the few settings that can be wrong in a way that still looks right.
    """
    text = value.strip().rstrip("/")
    if "://" not in text:
        text = f"https://{text}"

    parsed = urllib.parse.urlparse(text)
    if parsed.scheme != "https" or not parsed.netloc or " " in parsed.netloc:
        raise ImportError_(
            f"SUPABASE_URL is not a project URL: {value!r}\n"
            "  Wanted: https://<project-ref>.supabase.co\n"
            "  Dashboard: Project Settings -> Data API -> Project URL.\n"
            "  scripts/verify-accounts.sh checks this shape without printing a value."
        )
    return f"https://{parsed.netloc}"


def number(value: Any) -> float | None:
    try:
        parsed = float(str(value).strip())
    except (TypeError, ValueError):
        return None
    return parsed if parsed == parsed else None  # NaN is not a value


def clean(value: Any, limit: int = 300) -> str | None:
    text = str(value or "").strip()
    if not text:
        return None
    return text[:limit]


def off_rows(path: Path, limit: int | None) -> Iterator[dict[str, Any]]:
    """Open Food Facts CSV. Tab-separated, and the file is enormous."""
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8", errors="replace", newline="") as handle:
        # The export has fields containing unescaped quotes. QUOTE_NONE stops
        # csv treating one as the start of a quoted field and swallowing the
        # next several thousand rows into a single value.
        reader = csv.DictReader(handle, delimiter="\t", quoting=csv.QUOTE_NONE)
        yielded = 0
        for row in reader:
            name = clean(row.get("product_name"))
            barcode = clean(row.get("code"), 32)
            kcal = number(row.get("energy-kcal_100g"))

            if not name or not barcode or kcal is None:
                continue
            if not 0 <= kcal <= MAX_KCAL_PER_100G:
                continue

            yield {
                "source": "off",
                "barcode": barcode,
                "name": name,
                "brand": clean(row.get("brands"), 200),
                "kcal_per_100g": round(kcal, 2),
                "protein_g": positive(number(row.get("proteins_100g"))),
                "carbs_g": positive(number(row.get("carbohydrates_100g"))),
                "fat_g": positive(number(row.get("fat_100g"))),
            }
            yielded += 1
            if limit and yielded >= limit:
                return


def usda_rows(path: Path, limit: int | None) -> Iterator[dict[str, Any]]:
    """USDA FoodData Central JSON. No barcodes — these are generic foods."""
    data = json.loads(path.read_text(encoding="utf-8"))
    foods = data.get("FoundationFoods") or data.get("SRLegacyFoods") or data.get("foods") or []

    yielded = 0
    for food in foods:
        name = clean(food.get("description"))
        if not name:
            continue

        nutrients = {}
        for entry in food.get("foodNutrients", []):
            nutrient = entry.get("nutrient") or {}
            number_ = str(nutrient.get("number") or "")
            amount = number(entry.get("amount"))
            if amount is not None:
                nutrients[number_] = amount

        # 1008 is energy in kcal, 203 protein, 205 carbohydrate, 204 fat.
        kcal = nutrients.get("1008")
        if kcal is None or not 0 <= kcal <= MAX_KCAL_PER_100G:
            continue

        yield {
            "source": "usda",
            "barcode": None,
            "name": name,
            "brand": None,
            "kcal_per_100g": round(kcal, 2),
            "protein_g": positive(nutrients.get("203")),
            "carbs_g": positive(nutrients.get("205")),
            "fat_g": positive(nutrients.get("204")),
        }
        yielded += 1
        if limit and yielded >= limit:
            return


def positive(value: float | None) -> float | None:
    """The schema's checks are `>= 0`. A negative macro is a parse error, not a food."""
    if value is None or value < 0:
        return None
    return round(value, 2)


def push(url: str, key: str, rows: list[dict[str, Any]]) -> None:
    import urllib.error
    import urllib.request

    request = urllib.request.Request(
        f"{url}/rest/v1/foods",
        data=json.dumps(rows).encode(),
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            # Nothing comes back. The rows are large and there are a lot of them.
            "Prefer": "return=minimal",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            response.read()
    except urllib.error.HTTPError as error:
        raise ImportError_(
            f"insert failed ({error.code}): {error.read().decode()[:400]}"
        ) from None
    except urllib.error.URLError as error:
        raise ImportError_(transport_help(error)) from None


def transport_help(error: Exception) -> str:
    """Turn a transport failure into the thing to actually do about it.

    One case is worth naming rather than leaving as a traceback, because it is
    the machine rather than the code and it will break every other Python tool
    here in exactly the same way. A python.org install of Python does not use
    the system keychain: it ships its own OpenSSL with an empty trust store, so
    every HTTPS call fails with "unable to get local issuer certificate" until
    the bundled script has been run once. The vision spike hits the same wall
    the first time it calls a model API.

    Deliberately NOT worked around in code. Passing an unverified SSL context,
    or quietly pointing this one script at `certifi`, would fix the symptom here
    and leave the machine broken for everything else — and the first of those
    turns a transport error into a silent downgrade of the only thing protecting
    a service-role key in flight.
    """
    reason = str(getattr(error, "reason", error))
    if "CERTIFICATE_VERIFY_FAILED" not in reason:
        return f"could not reach the server: {reason}"

    version = f"{sys.version_info.major}.{sys.version_info.minor}"
    return (
        "TLS certificate verification failed, and this is almost certainly the "
        "Python install rather than the network.\n"
        "  A python.org Python ships its own OpenSSL with an empty trust store. "
        "Run its certificate installer once:\n"
        f"    /Applications/Python\\ {version}/Install\\ Certificates.command\n"
        "  Then run this again. Nothing was written."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--off", type=Path, help="Open Food Facts CSV (.csv or .csv.gz)")
    parser.add_argument("--usda", type=Path, help="USDA FoodData Central JSON")
    parser.add_argument("--limit", type=int, help="stop after this many rows per source")
    parser.add_argument("--dry-run", action="store_true", help="parse and report, write nothing")
    args = parser.parse_args()

    if not args.off and not args.usda:
        parser.error("give --off, --usda, or both")

    sources: list[Iterator[dict[str, Any]]] = []
    if args.off:
        sources.append(off_rows(args.off, args.limit))
    if args.usda:
        sources.append(usda_rows(args.usda, args.limit))

    # Loaded even for a dry run. The first version skipped this when nothing was
    # going to be written, which meant the rehearsal passed and the real run
    # failed on the one thing the rehearsal existed to catch — a malformed
    # SUPABASE_URL. A dry run that does not check the environment is not a dry
    # run of anything.
    url, key = load_env()
    print(f"    target: {url}")

    total = 0
    batch: list[dict[str, Any]] = []
    for source in sources:
        for row in source:
            batch.append(row)
            total += 1
            if len(batch) >= BATCH:
                if not args.dry_run:
                    push(url, key, batch)
                batch.clear()
                print(f"  {total:,} rows", end="\r", flush=True)

    if batch and not args.dry_run:
        push(url, key, batch)

    verb = "would import" if args.dry_run else "imported"
    print(f"OK  {verb} {total:,} foods" + " " * 20)
    if args.dry_run:
        print("    (nothing written — drop --dry-run to push)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ImportError_ as error:
        print(f"BAD {error}", file=sys.stderr)
        sys.exit(1)
