#!/usr/bin/env python3
"""Generate synthetic photos + matching ground truth for a no-cost demo run.

    python3 make_fixtures.py
    python3 run_baseline.py --provider mock \
        --photos fixtures/synthetic --truth fixtures/groundtruth.csv

These are coloured gradients, not food. The point is to exercise the whole pipeline
and produce a realistic-looking report before spending a single API call — so a
broken harness is discovered now rather than halfway through the one run you make
against 20 real meals.

**How the synthetic ground truth is built.** Rather than inventing numbers (which
would produce a meaningless 180% error and tell you nothing about the report's
shape), the truth is *derived from the mock provider's own predictions* with its
known +18% bias divided back out and a deterministic ±8% jitter added. That gives a
demo report with the error structure a real run has:

  · a recoverable systematic bias, so the bias-correction section shows a real gain
  · genuine noise, so bias-correction does not collapse to zero
  · confidence that tracks error, so the calibration section reads "monotonic"
  · a hidden `olive oil` item on some meals that the mock never predicts, so item
    recall is realistically below 100%

That last one is not arbitrary: invisible cooking oil is the single biggest thing
real vision models miss (§1.3), so the fixture reproduces the actual failure mode.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from ninetyvision import imaging  # noqa: E402
from ninetyvision.providers import MockProvider  # noqa: E402
from ninetyvision.schema import parse_estimate  # noqa: E402

FIXTURES = HERE / "fixtures"
PHOTOS = FIXTURES / "synthetic"

N_MEALS = 12
MOCK_BIAS_PCT = 18.0

# Meals that get an extra truth item the mock will never predict.
HIDDEN_OIL_ON = {2, 5, 8, 11}


def make_image(path: Path, seed: int) -> None:
    """Deterministic, non-uniform image so JPEG size and hashing behave realistically."""
    w, h = 1600, 1200
    img = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(img)
    for y in range(0, h, 8):
        draw.rectangle(
            [0, y, w, y + 8],
            fill=(
                (seed * 13 + y // 8) % 200 + 30,
                (seed * 29 + y // 5) % 200 + 30,
                (seed * 47 + y // 3) % 200 + 30,
            ),
        )
    for i in range(6):
        cx, cy = (seed * 97 + i * 211) % w, (seed * 61 + i * 137) % h
        r = 60 + (seed * 7 + i * 31) % 140
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=((seed * 3 + i * 40) % 256, (seed * 5 + i * 70) % 256, 90),
        )
    img.save(path, format="JPEG", quality=88)


def main() -> int:
    PHOTOS.mkdir(parents=True, exist_ok=True)
    provider = MockProvider(bias_pct=MOCK_BIAS_PCT)
    rows: list[list] = []

    for idx in range(1, N_MEALS + 1):
        pid = f"meal-{idx:03d}"
        photo = PHOTOS / f"{pid}.jpg"
        make_image(photo, seed=idx * 17)

        prepared = imaging.prepare(photo, max_edge=1024)
        estimate = parse_estimate(provider.estimate(prepared, "medium").raw_json)

        for item_no, item in enumerate(estimate.items):
            # Divide the known bias back out, then jitter deterministically so the
            # residual is real noise rather than exactly zero.
            jitter = 1 + (((idx * 7 + item_no * 13) % 17) - 8) / 100  # 0.92 .. 1.08
            factor = (1 + MOCK_BIAS_PCT / 100) * jitter
            rows.append([
                pid, item.name,
                round(item.grams_mid / factor, 1),
                round(item.kcal_mid / factor, 1),
                "SYNTHETIC — derived from the mock provider, not a measurement",
            ])

        if idx in HIDDEN_OIL_ON:
            rows.append([
                pid, "olive oil", 12, 106,
                "SYNTHETIC — the invisible item the mock never predicts",
            ])

    truth_path = FIXTURES / "groundtruth.csv"
    with truth_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["photo_id", "item_name", "actual_grams", "actual_kcal", "notes"])
        writer.writerows(rows)

    print(f"✓ {N_MEALS} synthetic photos → {PHOTOS.relative_to(HERE)}")
    print(f"✓ {len(rows)} truth rows → {truth_path.relative_to(HERE)}")
    print()
    print("Now run:")
    print("  python3 run_baseline.py --provider mock \\")
    print("      --photos fixtures/synthetic --truth fixtures/groundtruth.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
