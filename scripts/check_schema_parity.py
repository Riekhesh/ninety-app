#!/usr/bin/env python3
"""Check the Swift domain types still agree with the Postgres schema.

    python3 scripts/check_schema_parity.py

Prints `OK <what>` / `BAD <what>` and exits non-zero on any mismatch. Needs no
Mac, no Xcode and no database — it reads both sides as text — so it runs on
Ubuntu in CI alongside the RLS proof.

Why this is worth a script. The local store and Postgres hold the same rows,
and every enum here is stored as its bare string on both sides, so a value that
exists in one and not the other is a row that writes fine and fails to read
back — or worse, decodes to a silent default. Swift will not catch it: the
mapping between them is a string, and a string always compiles.

The failure this is really guarding against is the ordinary one. A later epic
adds `case fasting` to an entry method, or a migration adds a Postgres value,
and the other half is updated a week later or not at all.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "supabase" / "migrations" / "20260902000001_initial_schema.sql"
DOMAIN = ROOT / "Ninety" / "Data" / "Domain.swift"
MODELS = ROOT / "Ninety" / "Data" / "Models"

# Postgres type -> Swift type. `tier` is absent on purpose: it is generated from
# the design tokens, because a tier is a division and a division is a visual
# thing (ADR 0012), so its Swift home is DesignTokens.generated.swift.
ENUMS = {
    "food_source": "FoodSource",
    "entry_method": "EntryMethod",
    "weight_source": "WeightSource",
    "outbox_operation": "OutboxOperation",
    "goal_type": "GoalType",
    "sex": "Sex",
    "activity_level": "ActivityLevel",
}

# Postgres table -> the @Model that mirrors it. friendships and
# leaderboard_entries are Phase 4 and ship empty, so they have no local model.
TABLES = {
    "profiles": "Profile",
    "foods": "Food",
    "food_logs": "FoodLog",
    "photo_estimates": "PhotoEstimate",
    "weight_logs": "WeightLog",
    "health_samples": "HealthSample",
    "weekly_scores": "WeeklyScore",
    "sync_outbox": "OutboxEntry",
}


def postgres_enum_values(sql: str, name: str) -> list[str] | None:
    match = re.search(rf"create type {name} as enum \(([^)]*)\)", sql, re.S)
    if not match:
        return None
    return sorted(value.strip().strip("'") for value in match.group(1).split(","))


def swift_enum_values(swift: str, name: str) -> list[str] | None:
    """The raw values a Swift enum stores, which is what reaches the database.

    Handles both shapes the file uses: `case a, b, c` where the raw value is the
    case name, and `case veryActive = "very_active"` where it is not.
    """
    body = re.search(rf"enum {name}: String.*?\n}}", swift, re.S)
    if not body:
        return None

    values: set[str] = set()
    for line, explicit in re.findall(r"case ([\w, ]+?)(?: = \"(\w+)\")?$", body.group(0), re.M):
        for case_name in line.split(","):
            values.add(explicit or case_name.strip())
    return sorted(values)


def main() -> int:
    sql = SCHEMA.read_text()
    swift = DOMAIN.read_text()
    failures = 0

    for pg_name, swift_name in ENUMS.items():
        want = postgres_enum_values(sql, pg_name)
        got = swift_enum_values(swift, swift_name)
        if want is None:
            print(f"BAD Postgres has no enum `{pg_name}` — the schema moved without Domain.swift")
            failures += 1
        elif got is None:
            print(f"BAD Domain.swift has no `enum {swift_name}: String` for Postgres `{pg_name}`")
            failures += 1
        elif want != got:
            print(
                f"BAD `{pg_name}` and `{swift_name}` disagree — "
                f"only in Postgres: {sorted(set(want) - set(got)) or 'none'}, "
                f"only in Swift: {sorted(set(got) - set(want)) or 'none'}"
            )
            failures += 1
        else:
            print(f"OK  {pg_name} == {swift_name} ({len(want)} values)")

    for table, model in TABLES.items():
        if not re.search(rf"create table {table} \(", sql):
            print(f"BAD migration 001 has no table `{table}`")
            failures += 1
        elif not (MODELS / f"{model}.swift").exists():
            print(f"BAD `{table}` has no local model — expected Ninety/Data/Models/{model}.swift")
            failures += 1
    if not failures:
        print(f"OK  all {len(TABLES)} live tables have a local model")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
