#!/usr/bin/env python3
"""Run the photo-accuracy baseline (Spike B, §0.7).

    # Prove the pipeline works — no API key, no cost, no network
    python3 run_baseline.py --provider mock --photos fixtures/synthetic

    # The real thing, against your own 20 weighed meals
    python3 run_baseline.py --photos photos --truth groundtruth.csv

    # Test §1.3's "downscaling barely hurts accuracy" claim
    for edge in 2576 1568 1024 768; do
      python3 run_baseline.py --max-edge $edge --tag "edge-$edge"
    done

    # Measure run-to-run variance on identical images
    python3 run_baseline.py --repeats 3

Every run writes a JSONL to `runs/` whose first line is a manifest recording model,
prompt hash, effort and image size. Without that, a measured error rate is not
reproducible and therefore not worth quoting.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from notchvision import imaging, providers  # noqa: E402
from notchvision.dataset import GroundTruthError, load_truth  # noqa: E402
from notchvision.prompts import PROMPT_VERSION, prompt_hash  # noqa: E402
from notchvision.providers import VisionRefusal  # noqa: E402


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--photos", type=Path, default=HERE / "photos",
                   help="directory of meal photos (default: photos/)")
    p.add_argument("--truth", type=Path, default=HERE / "groundtruth.csv",
                   help="ground-truth CSV (default: groundtruth.csv)")
    p.add_argument("--provider", choices=providers.PROVIDERS, default="gemini",
                   help="default: gemini (see ADR 0010)")
    p.add_argument("--model", default=None,
                   help="override the provider default, e.g. gemini-2.5-pro. "
                        "Model ids move faster than this harness does.")
    p.add_argument("--effort", choices=("low", "medium", "high", "xhigh", "max"),
                   default="medium",
                   help="cost/quality lever, ANTHROPIC ONLY (default: medium). "
                        "Ignored by other providers; recorded in the manifest either way.")
    p.add_argument("--max-edge", type=int, default=1024,
                   help=f"longest edge in px, 1..{imaging.MAX_SUPPORTED_EDGE} "
                        "(default: 1024, per §1.3)")
    p.add_argument("--repeats", type=int, default=1,
                   help="calls per image; >1 measures run-to-run variance")
    p.add_argument("--limit", type=int, default=None,
                   help="only the first N photos (for a cheap smoke test)")
    p.add_argument("--tag", default=None, help="label for the run filename")
    p.add_argument("--no-cache", action="store_true",
                   help="ignore the response cache and re-call the model")
    p.add_argument("--no-analyse", action="store_true",
                   help="write the run but skip the report")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not args.photos.is_dir():
        print(f"✗ {args.photos} is not a directory.", file=sys.stderr)
        print("  Put 20 photos of meals you have weighed in it. See README.md §Protocol.",
              file=sys.stderr)
        return 2

    photos = imaging.discover(args.photos)
    if not photos:
        print(f"✗ no supported images in {args.photos}", file=sys.stderr)
        return 2
    if args.limit:
        photos = photos[: args.limit]

    # Ground truth is optional at run time — you can collect responses first and
    # score later. Analysis needs it.
    truth = None
    try:
        truth = load_truth(args.truth)
    except GroundTruthError as exc:
        print(f"! ground truth unavailable: {exc}")
        print("  Responses will still be collected; run analyse.py once it exists.\n")

    if truth:
        missing = [p.stem for p in photos if p.stem not in truth]
        if missing:
            print(f"! {len(missing)} photo(s) have no ground-truth rows and will be "
                  f"collected but not scored: {', '.join(missing[:6])}"
                  f"{'…' if len(missing) > 6 else ''}\n")

    provider = providers.build(args.provider, args.model)
    cache = imaging.ResponseCache(HERE / ".cache")

    run_id = f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:6]}"
    name = f"{run_id}-{args.tag}" if args.tag else run_id
    runs_dir = HERE / "runs"
    runs_dir.mkdir(exist_ok=True)
    out_path = runs_dir / f"{name}.jsonl"

    manifest = {
        "kind": "manifest",
        "run_id": run_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "provider": provider.name,
        "model": provider.model,
        "effort": args.effort,
        "max_edge": args.max_edge,
        "repeats": args.repeats,
        "prompt_version": PROMPT_VERSION,
        "prompt_hash": prompt_hash(),
        "n_photos": len(photos),
        "photos_dir": str(args.photos),
        "truth_file": str(args.truth),
    }

    total = len(photos) * args.repeats
    print(f"▶ {provider.name} · {provider.model} · effort={args.effort} · "
          f"{args.max_edge}px · {len(photos)} photos × {args.repeats} = {total} calls")
    print(f"  → {out_path.relative_to(HERE)}\n")

    refusals = 0
    failures = 0

    with out_path.open("w", encoding="utf-8") as fh:
        fh.write(json.dumps(manifest) + "\n")

        for idx, photo in enumerate(photos, start=1):
            try:
                prepared = imaging.prepare(photo, max_edge=args.max_edge)
            except Exception as exc:  # noqa: BLE001 - a bad image should not stop the run
                print(f"  [{idx}/{len(photos)}] {photo.name}: unreadable ({exc})")
                failures += 1
                continue

            for run in range(args.repeats):
                # Cache only single-run mode: with --repeats we are deliberately
                # measuring variance, and a cache would return the same answer.
                cacheable = args.repeats == 1 and not args.no_cache
                cached = (
                    cache.get(prepared.sha256, provider.model, PROMPT_VERSION, args.effort)
                    if cacheable
                    else None
                )

                if cached is not None:
                    record = cached | {"photo_id": photo.stem, "run": run, "cached": True}
                else:
                    try:
                        result = provider.estimate(prepared, args.effort)
                    except VisionRefusal as exc:
                        print(f"  [{idx}/{len(photos)}] {photo.stem} run {run}: "
                              f"REFUSED — {exc}")
                        refusals += 1
                        continue
                    except Exception as exc:  # noqa: BLE001
                        print(f"  [{idx}/{len(photos)}] {photo.stem} run {run}: "
                              f"FAILED — {type(exc).__name__}: {exc}")
                        failures += 1
                        continue

                    record = {
                        "photo_id": photo.stem,
                        "run": run,
                        "cached": False,
                        "raw_json": result.raw_json,
                        "usage": {
                            "input_tokens": result.usage.input_tokens,
                            "output_tokens": result.usage.output_tokens,
                            "cache_write_tokens": result.usage.cache_write_tokens,
                            "cache_read_tokens": result.usage.cache_read_tokens,
                        },
                        "cost_usd": result.usage.cost_usd(result.model),
                        "latency_ms": result.latency_ms,
                        "model": result.model,
                        "image": {
                            "width": prepared.width,
                            "height": prepared.height,
                            "bytes_out": prepared.bytes_out,
                            "bytes_in": prepared.bytes_in,
                            "sha256": prepared.sha256,
                            "estimated_image_tokens": prepared.estimated_image_tokens,
                        },
                    }
                    if cacheable:
                        cache.put(
                            prepared.sha256, provider.model, PROMPT_VERSION,
                            args.effort, record,
                        )

                fh.write(json.dumps(record) + "\n")

                n_items = len(record["raw_json"].get("items", []))
                kcal = sum(
                    (i.get("kcal_low", 0) + i.get("kcal_high", 0)) / 2
                    for i in record["raw_json"].get("items", [])
                )
                flag = " (cached)" if record.get("cached") else ""
                print(f"  [{idx}/{len(photos)}] {photo.stem} run {run}: "
                      f"{n_items} item(s), {kcal:.0f} kcal, "
                      f"{record['latency_ms']}ms{flag}")

    print(f"\n✓ {out_path.relative_to(HERE)}")
    print(f"  cache: {cache.hits} hit / {cache.misses} miss"
          + (f" · {refusals} refused" if refusals else "")
          + (f" · {failures} failed" if failures else ""))

    if args.no_analyse or truth is None:
        if truth is None:
            print("\n  Fill in groundtruth.csv, then: python3 analyse.py")
        return 0

    print()
    import analyse

    return analyse.main(["--run", str(out_path), "--truth", str(args.truth)])


if __name__ == "__main__":
    sys.exit(main())
