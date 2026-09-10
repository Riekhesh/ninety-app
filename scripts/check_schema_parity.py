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
MIGRATIONS = ROOT / "supabase" / "migrations"
DOMAIN = ROOT / "Ninety" / "Data" / "Domain.swift"
MODELS = ROOT / "Ninety" / "Data" / "Models"
PAYLOAD = ROOT / "Ninety" / "Sync" / "SyncPayload.swift"
REPOSITORIES = ROOT / "Ninety" / "Data" / "Repositories"
SYNC_TABLE = ROOT / "Ninety" / "Sync" / "SyncTable.swift"

# Postgres type -> Swift type. `tier` is absent on purpose: it is generated from
# the design tokens, because a tier is a division and a division is a visual
# thing (ADR 0012), so its Swift home is DesignTokens.generated.swift.
ENUMS = {
    "food_source": "FoodSource",
    "entry_method": "EntryMethod",
    "weight_source": "WeightSource",
    "outbox_operation": "OutboxOperation",
    "goal_type": "GoalType",
    "meal_slot": "MealSlot",
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


# Names NSManagedObject and NSObject already own. SwiftData @Model types are
# backed by NSManagedObject, so a stored property with one of these shadows the
# real thing: it compiles, it runs, and it traps inside ModelContext.save() with
# a message naming neither the property nor the model.
#
# This is here rather than in SwiftLint because it is a fact about the models,
# and this is the script that reads them. It was added after `OutboxEntry.entity`
# cost an afternoon — the first time anything ever executed that save path.
RESERVED_PROPERTY_NAMES = {
    "entity",
    "objectID",
    "managedObjectContext",
    "isDeleted",
    "isFault",
    "isInserted",
    "isUpdated",
    "hasChanges",
    "hasPersistentChangedValues",
    "faultingState",
    "description",
    "debugDescription",
    "hash",
    "superclass",
    "classForCoder",
}


def check_reserved_property_names() -> bool:
    """No @Model stores a property NSManagedObject already defines."""
    clean = True
    for path in sorted(MODELS.glob("*.swift")):
        source = path.read_text()
        for match in re.finditer(r"^\s*var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:", source, re.M):
            name = match.group(1)
            if name in RESERVED_PROPERTY_NAMES:
                line = source[: match.start()].count("\n") + 1
                print(
                    f"BAD {path.name}:{line} `var {name}` shadows NSManagedObject.{name} — "
                    f"it will trap inside ModelContext.save(), not at compile time"
                )
                clean = False
    if clean:
        print("OK  no model property shadows an NSManagedObject one")
    return clean


# Columns the outbox drain deliberately does not send, and why. Everything else
# that is `not null` with no default has to appear in SyncPayload, or the first
# write of that table after a day offline comes back 400.
#
# Added with P1-I. The drain builds its JSON by hand — Postgres column names are
# not Swift property names and neither can be inferred from the other — so the
# mapping is exactly the kind of thing that is right on the day it is written
# and wrong two epics later.
DELIBERATELY_NOT_SENT = {
    # Derived by trigger from logged_at so the client cannot move §2.3's
    # 48-hour window. Sending one would be rejected on principle.
    ("food_logs", "locked_at"),
}


def schema() -> str:
    """Every migration, concatenated in the order `supabase db push` applies them.

    **Not migration 001 alone, and that changed with 007.** Until meal slots the
    whole live schema was one file, so reading one file was the same thing as
    reading the schema. It is not any more: a `create type` or an `alter table
    ... add column` in a later migration is as real as anything in 001, and a
    checker that cannot see it reports a column the drain sends as one that does
    not exist. Filename order is the applied order — that is what `supabase db
    push` guarantees — so sorting the paths is enough.
    """
    return "\n".join(path.read_text() for path in sorted(MIGRATIONS.glob("*.sql")))


def postgres_columns(sql: str, table: str) -> dict[str, str]:
    """Column name -> the rest of its declaration, across every migration."""
    match = re.search(rf"create table {table} \((.*?)\n\);", sql, re.S)
    if not match:
        return {}

    columns: dict[str, str] = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("--"):
            continue
        name, _, rest = line.partition(" ")
        if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
            continue
        if name in {"constraint", "unique", "check", "primary", "foreign"}:
            continue
        columns[name] = rest

    # Anything a later migration bolted on. `add column` only: a `drop column`
    # would need the same treatment, and there has never been one — when there
    # is, this is the function that has to learn about it rather than the caller.
    for name, rest in re.findall(
        rf"alter table {table}\s+add column\s+(?:if not exists\s+)?([a-z][a-z0-9_]*)\s+([^;]+);",
        sql,
        re.S,
    ):
        columns[name] = " ".join(rest.split())
    return columns


def sync_table_names() -> dict[str, str]:
    """Swift case name -> Postgres table, read off SyncTable."""
    source = SYNC_TABLE.read_text()
    body = re.search(r"enum SyncTable: String.*?\n}", source, re.S)
    if not body:
        return {}
    names: dict[str, str] = {}
    for case_name, explicit in re.findall(r"case (\w+)(?: = \"(\w+)\")?$", body.group(0), re.M):
        names[case_name] = explicit or case_name
    return names


def payload_columns() -> dict[str, set[str]]:
    """Postgres table -> the columns SyncPayload writes into it."""
    source = PAYLOAD.read_text()
    tables = sync_table_names()
    written: dict[str, set[str]] = {}
    for block in source.split("table: .")[1:]:
        case_name = re.match(r"(\w+)", block)
        if not case_name or case_name.group(1) not in tables:
            continue
        columns = re.search(r"columns: \[(.*?)\n {12}\]", block, re.S)
        if not columns:
            continue
        written[tables[case_name.group(1)]] = set(re.findall(r'"([a-z][a-z0-9_]*)":', columns.group(1)))
    return written


def check_enqueued_tables() -> bool:
    """Every table name a repository enqueues is one the drain can map.

    `OutboxEntry.tableName` is a String, deliberately — a stored enum turns an
    unrecognised value into a decode failure at fetch time, which takes the whole
    queue down instead of one row of it. The cost of that choice is that a typo in
    an `enqueue` call compiles, writes, and then sits in the outbox forever being
    counted as stuck. This is the check that would have been the compiler's job.
    """
    known = set(sync_table_names().values())
    if not known:
        print("BAD could not read the tables out of SyncTable.swift")
        return False

    clean = True
    seen: set[str] = set()
    for path in sorted(REPOSITORIES.glob("*.swift")):
        for match in re.finditer(r'enqueue\([^)]*?tableName: "([^"]+)"', path.read_text(), re.S):
            table = match.group(1)
            seen.add(table)
            if table not in known:
                print(
                    f"BAD {path.name} enqueues `{table}`, which SyncTable cannot map — "
                    f"the row will queue forever and be counted as stuck"
                )
                clean = False

    if clean:
        print(f"OK  all {len(seen)} enqueued table names are ones the drain can map")
    return clean


def check_sync_payload(sql: str) -> bool:
    """Every column the drain sends exists, and every required one is sent."""
    if not PAYLOAD.exists():
        print("BAD Ninety/Sync/SyncPayload.swift is missing — the drain has no row builder")
        return False

    clean = True
    written = payload_columns()
    if not written:
        print("BAD could not read any columns out of SyncPayload.swift")
        return False

    for table, columns in sorted(written.items()):
        declared = postgres_columns(sql, table)
        if not declared:
            print(f"BAD SyncPayload writes to `{table}`, which no migration creates")
            clean = False
            continue

        for column in sorted(columns - set(declared)):
            print(f"BAD SyncPayload sends `{table}.{column}`, which no migration creates")
            clean = False

        for column, declaration in sorted(declared.items()):
            required = "not null" in declaration and "default" not in declaration
            if not required or column in columns:
                continue
            if (table, column) in DELIBERATELY_NOT_SENT:
                continue
            print(
                f"BAD `{table}.{column}` is not null with no default and SyncPayload never sends it — "
                f"the first write after a day offline will come back 400"
            )
            clean = False

    if clean:
        print(f"OK  every column the outbox sends exists, across {len(written)} tables")
    return clean


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
    sql = schema()
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
            print(f"BAD no migration creates the table `{table}`")
            failures += 1
        elif not (MODELS / f"{model}.swift").exists():
            print(f"BAD `{table}` has no local model — expected Ninety/Data/Models/{model}.swift")
            failures += 1
    if not failures:
        print(f"OK  all {len(TABLES)} live tables have a local model")

    if not check_reserved_property_names():
        failures += 1

    if not check_sync_payload(sql):
        failures += 1

    if not check_enqueued_tables():
        failures += 1

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
