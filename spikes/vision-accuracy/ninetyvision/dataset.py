"""Load ground truth and run records.

Ground truth is a CSV rather than JSON on purpose: you will be typing it by hand
while weighing 20 meals, and a spreadsheet is the right tool for that. One row per
food item, several rows per photo.

    photo_id,item_name,actual_grams,actual_kcal,notes
    meal-001,porridge with milk,250,320,60g oats + 190ml semi-skimmed
    meal-001,banana,118,105,weighed peeled

`photo_id` must match the photo filename stem, so `meal-001.jpg` ↔ `meal-001`.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

from .metrics import TruthItem, TruthMeal

REQUIRED_COLUMNS = {"photo_id", "item_name", "actual_grams", "actual_kcal"}


class GroundTruthError(ValueError):
    pass


def load_truth(path: Path) -> dict[str, TruthMeal]:
    """Parse the ground-truth CSV into meals keyed by photo_id."""
    if not path.exists():
        raise GroundTruthError(
            f"{path} not found. Copy groundtruth.example.csv to groundtruth.csv "
            "and fill it in with your own weighed meals."
        )

    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise GroundTruthError(f"{path} is empty")
        missing = REQUIRED_COLUMNS - {c.strip() for c in reader.fieldnames}
        if missing:
            raise GroundTruthError(
                f"{path} is missing required column(s): {', '.join(sorted(missing))}"
            )

        grouped: dict[str, list[TruthItem]] = {}
        for line_no, row in enumerate(reader, start=2):
            pid = (row.get("photo_id") or "").strip()
            if not pid or pid.startswith("#"):
                continue
            try:
                grams = float(row["actual_grams"])
                kcal = float(row["actual_kcal"])
            except (TypeError, ValueError) as exc:
                raise GroundTruthError(
                    f"{path}:{line_no} — actual_grams and actual_kcal must be numbers "
                    f"(got {row.get('actual_grams')!r}, {row.get('actual_kcal')!r})"
                ) from exc
            if grams <= 0 or kcal < 0:
                raise GroundTruthError(
                    f"{path}:{line_no} — grams must be > 0 and kcal >= 0"
                )
            grouped.setdefault(pid, []).append(
                TruthItem(
                    name=(row.get("item_name") or "").strip() or "unnamed",
                    grams=grams,
                    kcal=kcal,
                )
            )

    if not grouped:
        raise GroundTruthError(f"{path} has a header but no data rows")

    return {
        pid: TruthMeal(photo_id=pid, items=tuple(items))
        for pid, items in grouped.items()
    }


def load_run(path: Path) -> tuple[dict, list[dict]]:
    """Read a run JSONL. First line is the manifest; the rest are records."""
    lines = [ln for ln in path.read_text().splitlines() if ln.strip()]
    if not lines:
        raise ValueError(f"{path} is empty")
    manifest = json.loads(lines[0])
    if manifest.get("kind") != "manifest":
        raise ValueError(f"{path}: first line is not a manifest")
    return manifest, [json.loads(ln) for ln in lines[1:]]
