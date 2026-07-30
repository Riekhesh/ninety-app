#!/usr/bin/env python3
"""Score a run against ground truth and write the baseline report.

    python3 analyse.py                         # newest run in runs/
    python3 analyse.py --run runs/2026….jsonl
    python3 analyse.py --compare runs/*.jsonl   # one table, several runs

`--compare` is what turns the sweeps into findings: same photos, same ground truth,
different model / image size / effort, one table. That is the difference between
"here is our error rate" and "here is the cost/accuracy curve, and here is where we
chose to sit on it."
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from notchvision import metrics, report  # noqa: E402
from notchvision.dataset import GroundTruthError, load_run, load_truth  # noqa: E402
from notchvision.schema import EstimateParseError, parse_estimate  # noqa: E402


def newest_run() -> Path | None:
    runs = sorted((HERE / "runs").glob("*.jsonl"))
    return runs[-1] if runs else None


def score(run_path: Path, truth_path: Path) -> tuple[metrics.Summary, dict, list]:
    manifest, records = load_run(run_path)
    truth = load_truth(truth_path)

    meals: list[metrics.MealResult] = []
    items: list[metrics.ItemResult] = []
    costs: list[float] = []
    latencies: list[int] = []
    n_predicted = 0
    warnings = 0

    for rec in records:
        pid = rec["photo_id"]
        if pid not in truth:
            continue  # collected but not weighed — not an error
        try:
            estimate = parse_estimate(rec["raw_json"])
        except EstimateParseError as exc:
            print(f"! {pid} run {rec.get('run')}: unparseable ({exc})", file=sys.stderr)
            continue

        warnings += len(estimate.warnings)
        n_predicted += len(estimate.items)

        meal, item_results = metrics.score_meal(truth[pid], estimate, rec.get("run", 0))
        meals.append(meal)
        items.extend(item_results)

        if (cost := rec.get("cost_usd")) is not None:
            costs.append(float(cost))
        if (lat := rec.get("latency_ms")) is not None:
            latencies.append(int(lat))

    summary = metrics.summarise(
        meals, items,
        n_items_predicted=n_predicted,
        costs=costs,
        latencies=latencies,
        parse_warnings=warnings,
    )

    # Token totals straight from the run records — real usage, not an estimate.
    for rec in records:
        u = rec.get("usage") or {}
        summary.total_input_tokens += int(u.get("input_tokens", 0) or 0)
        summary.total_output_tokens += int(u.get("output_tokens", 0) or 0)
        summary.cache_read_tokens += int(u.get("cache_read_tokens", 0) or 0)

    worst = sorted(meals, key=lambda m: m.abs_pct, reverse=True)
    return summary, manifest, worst


def compare(paths: list[Path], truth_path: Path) -> str:
    rows = []
    for p in paths:
        try:
            s, m, _ = score(p, truth_path)
        except Exception as exc:  # noqa: BLE001
            print(f"! skipping {p.name}: {exc}", file=sys.stderr)
            continue
        calls = max(1, s.n_meals * max(1, s.n_runs))
        rows.append((m, s, s.total_cost_usd / calls))

    if not rows:
        return "No runs could be scored."

    out = ["# Spike B — run comparison", "",
           "Same photos, same ground truth. Only the run configuration differs.", "",
           "| Model | Effort | Edge | MAPE | Bias | Noise | ≤20% | Cover | $/img |",
           "|---|---|---:|---:|---:|---:|---:|---:|---:|"]

    def f(v, unit="%", dp=1):
        return "—" if v is None else f"{v:.{dp}f}{unit}"

    for m, s, per_img in sorted(rows, key=lambda r: r[1].mape or 1e9):
        out.append(
            f"| `{m.get('model','?')}` | {m.get('effort','?')} | {m.get('max_edge','?')}px "
            f"| {f(s.mape)} | {f(s.bias)} | {f(s.noise,' pts')} | {f(s.within_20)} "
            f"| {f(s.coverage)} | ${per_img:.4f} |"
        )

    out += ["", "**Reading this table.** Compare *bias* and *noise* separately, not just "
            "MAPE — a run with high bias and low noise is better for trend tracking than "
            "the reverse at the same MAPE, because bias is a constant you can subtract. "
            "If the `edge` rows are flat on MAPE, §1.3's downscaling claim is confirmed "
            "and the smallest edge is free accuracy-wise.", ""]
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--run", type=Path, default=None, help="run JSONL (default: newest)")
    ap.add_argument("--truth", type=Path, default=HERE / "groundtruth.csv")
    ap.add_argument("--compare", type=Path, nargs="+", default=None,
                    help="score several runs into one comparison table")
    ap.add_argument("--out", type=Path, default=None,
                    help="write markdown here (default: alongside the run)")
    args = ap.parse_args(argv)

    try:
        if args.compare:
            text = compare(args.compare, args.truth)
            out = args.out or HERE / "runs" / "comparison.md"
        else:
            run_path = args.run or newest_run()
            if run_path is None:
                print("✗ no runs found. Run run_baseline.py first.", file=sys.stderr)
                return 2
            summary, manifest, worst = score(run_path, args.truth)
            if summary.n_meals == 0:
                print("✗ nothing scored — no photo_id in the run matched a "
                      "photo_id in the ground truth. Filenames must match the CSV: "
                      "meal-001.jpg ↔ meal-001", file=sys.stderr)
                return 1
            text = report.render(summary, manifest, worst)
            out = args.out or run_path.with_suffix(".md")
    except GroundTruthError as exc:
        print(f"✗ {exc}", file=sys.stderr)
        return 2

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(text)
    print(f"\n✓ written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
