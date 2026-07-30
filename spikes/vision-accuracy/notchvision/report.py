"""Render a Summary as markdown, with interpretation rather than just numbers.

§0.7: *"That measured baseline error rate is worth more than the feature itself."*
A table of numbers is not worth more than the feature — a number plus what it means
for the build is. So the report states, for each headline metric, what the value
implies and what to do about it.

The output is designed to be pasted straight into `docs/phase-0/07-spike-findings.md`.
"""

from __future__ import annotations

from .metrics import MealResult, Summary


def _n(v: float | None, unit: str = "%", dp: int = 1) -> str:
    return "—" if v is None else f"{v:.{dp}f}{unit}"


def _verdict(summary: Summary) -> list[str]:
    """The paragraph a reader actually needs. Derived from the numbers, not typed."""
    out: list[str] = []

    if summary.mape is None:
        return ["No meals scored — nothing to interpret."]

    # ── Is the error systematic (harmless to a trend) or random (not)? ──
    if summary.bias is not None and summary.noise is not None:
        direction = "over" if summary.bias > 0 else "under"
        out.append(
            f"**The model reads {direction} by {abs(summary.bias):.1f}% on average, "
            f"with a spread of {summary.noise:.1f} points.** "
            f"Mean absolute error is {summary.mape:.1f}%."
        )
        if summary.bias_corrected_mape is not None and summary.mape:
            gain = summary.bias_correction_gain or 0
            share = gain / summary.mape * 100 if summary.mape else 0
            if share >= 35:
                out.append(
                    f"Removing that systematic component drops the error to "
                    f"**{summary.bias_corrected_mape:.1f}%** — {share:.0f}% of the total "
                    f"error is a constant factor. §1.3's argument holds for this model: "
                    f"the error mostly does not affect the *trend*, and a single "
                    f"calibration constant in the Edge Function is worth "
                    f"{gain:.1f} points of accuracy. Worth doing in Phase 1."
                )
            else:
                out.append(
                    f"Removing that systematic component only gets to "
                    f"**{summary.bias_corrected_mape:.1f}%** — just {share:.0f}% of the "
                    f"error is a constant factor, so most of it is genuine noise. "
                    f"A calibration constant will not help much, and §1.3's "
                    f"\"consistent error still tracks the trend\" argument is weaker "
                    f"here than it sounds. **Lean harder on the ranges and the "
                    f"correction UI.**"
                )

    # ── Which half is wrong: what, or how much? ──
    if summary.portion_mape is not None and summary.density_mape is not None:
        if summary.portion_mape > summary.density_mape * 1.5:
            out.append(
                f"**Portion is the problem, not identification** "
                f"(portion {summary.portion_mape:.1f}% vs energy-density "
                f"{summary.density_mape:.1f}%). The model knows what the food is and "
                f"is wrong about how much. Prompt work should go into size "
                f"referencing — plates, cutlery, hands — and the correction UI should "
                f"make adjusting *grams* the fastest possible interaction."
            )
        elif summary.density_mape > summary.portion_mape * 1.5:
            out.append(
                f"**Identification is the problem, not portion** "
                f"(energy-density {summary.density_mape:.1f}% vs portion "
                f"{summary.portion_mape:.1f}%). The model judges size acceptably but "
                f"misreads the food or its preparation. Prompt work should go into "
                f"cooking method and hidden fats, and correction should surface "
                f"*swapping the item* rather than nudging grams."
            )
        else:
            out.append(
                f"Portion error ({summary.portion_mape:.1f}%) and energy-density error "
                f"({summary.density_mape:.1f}%) are comparable, so neither dominates. "
                f"The correction UI needs both paths to be cheap."
            )

    # ── Should the confidence chip ship? ──
    if summary.confidence_monotonic is True:
        hi = _n(summary.confidence_mape.get("high"))
        lo = _n(summary.confidence_mape.get("low"))
        out.append(
            f"**Confidence is informative and should ship** — error rises as "
            f"confidence falls (high {hi} → low {lo}). §1.3's instruction to show "
            f"confidence is justified by the data, and low-confidence items are worth "
            f"flagging for correction."
        )
    elif summary.confidence_monotonic is False:
        out.append(
            "**Confidence is NOT informative on this data** — stated confidence does "
            "not order by actual error. Showing it would be decoration that implies "
            "a reliability the model does not have. Either fix it in the prompt and "
            "re-measure, or do not ship the chip."
        )

    # ── Is the range honest, or just wide? ──
    if summary.coverage is not None and summary.mean_range_width_pct is not None:
        if summary.coverage >= 70 and summary.mean_range_width_pct <= 60:
            out.append(
                f"Ranges are honest: they contain the true value "
                f"{summary.coverage:.0f}% of the time at a mean width of "
                f"{summary.mean_range_width_pct:.0f}% of the midpoint. Tight enough "
                f"to be useful, wide enough to be true."
            )
        elif summary.coverage >= 70:
            out.append(
                f"Ranges contain the truth {summary.coverage:.0f}% of the time, but "
                f"they are **wide** ({summary.mean_range_width_pct:.0f}% of midpoint). "
                f"High coverage bought with vagueness. Push the prompt for tighter "
                f"ranges and watch coverage as you do."
            )
        else:
            out.append(
                f"Ranges miss the true value {100 - summary.coverage:.0f}% of the "
                f"time — **overconfident**. A range users learn to distrust is worse "
                f"than no range. Widen via the prompt and re-measure."
            )

    # ── Same photo, different answers ──
    if summary.mean_run_cv is not None:
        if summary.mean_run_cv > 10:
            out.append(
                f"**Run-to-run variance is high** ({summary.mean_run_cv:.1f}% mean "
                f"coefficient of variation on identical images, worst case "
                f"{_n(summary.max_run_cv)}). The same photo gets materially different "
                f"answers, which puts a hard floor under how good this feature can "
                f"get — prompt tuning cannot fix it. Consider averaging repeated "
                f"calls, at proportional cost."
            )
        else:
            out.append(
                f"Run-to-run variance is low ({summary.mean_run_cv:.1f}% mean CV on "
                f"identical images), so the model is at least self-consistent and a "
                f"single call is defensible."
            )

    if summary.refusals:
        out.append(
            f"⚠️ {summary.refusals} request(s) were declined by safety classifiers. "
            f"Unexpected for food photos — inspect those images."
        )
    if summary.parse_warnings:
        out.append(
            f"{summary.parse_warnings} response(s) needed repair (inverted or negative "
            f"ranges). The schema guarantees shape, not sense — the Edge Function will "
            f"need the same validation."
        )

    return out


def render(
    summary: Summary,
    manifest: dict,
    worst: list[MealResult] | None = None,
) -> str:
    m = manifest
    L: list[str] = []

    L.append("# Spike B — photo-estimate accuracy baseline")
    L.append("")
    L.append(
        f"**{summary.n_meals} meals · {summary.n_runs} run(s) per meal · "
        f"`{m.get('model', '?')}` · effort `{m.get('effort', '?')}` · "
        f"{m.get('max_edge', '?')}px longest edge**"
    )
    L.append("")
    L.append(
        f"Run `{m.get('run_id', '?')}` · provider `{m.get('provider', '?')}` · "
        f"prompt `{m.get('prompt_version', '?')}` (`{m.get('prompt_hash', '?')}`) · "
        f"{m.get('started_at', '?')}"
    )
    L.append("")

    if m.get("provider") == "mock":
        L.append(
            "> ⚠️ **Synthetic data from the mock provider.** No model was called. This "
            "run proves the pipeline works; it is not a measurement of anything. Run "
            "with `--provider anthropic` against your own weighed meals for a real "
            "baseline."
        )
        L.append("")

    L.append("## What this says")
    L.append("")
    for para in _verdict(summary):
        L.append(f"- {para}")
    L.append("")

    L.append("## Headline — meal total energy")
    L.append("")
    L.append("| Metric | Value | What it means |")
    L.append("|---|---:|---|")
    L.append(
        f"| Mean absolute error (MAPE) | {_n(summary.mape)} | The headline number. |"
    )
    L.append(
        f"| Median absolute error | {_n(summary.median_ape)} | Robust to one bad photo. |"
    )
    L.append(
        f"| **Bias** (mean signed) | {_n(summary.bias)} | Systematic — correctable. |"
    )
    L.append(
        f"| **Noise** (std dev of signed) | {_n(summary.noise, ' pts')} | Random — not correctable. |"
    )
    L.append(
        f"| Bias-corrected MAPE | {_n(summary.bias_corrected_mape)} | Error left after removing bias. |"
    )
    L.append(f"| Within 10% | {_n(summary.within_10)} | |")
    L.append(
        f"| Within 20% | {_n(summary.within_20)} | §1.3's stated tolerance for dietitians. |"
    )
    L.append(f"| Within 30% | {_n(summary.within_30)} | |")
    L.append("")

    L.append("## Decomposition — *what* vs *how much*")
    L.append("")
    L.append("| Metric | Value |")
    L.append("|---|---:|")
    L.append(f"| Item recall (truth items found) | {_n(summary.item_recall)} |")
    L.append(f"| Item precision (predictions that were real) | {_n(summary.item_precision)} |")
    L.append(f"| Portion error, absolute | {_n(summary.portion_mape)} |")
    L.append(f"| Portion bias | {_n(summary.portion_bias)} |")
    L.append(f"| Energy-density error, absolute | {_n(summary.density_mape)} |")
    L.append(f"| Energy-density bias | {_n(summary.density_bias)} |")
    L.append("")

    L.append("## Range honesty")
    L.append("")
    L.append("| Metric | Value |")
    L.append("|---|---:|")
    L.append(f"| Coverage (truth inside stated range) | {_n(summary.coverage)} |")
    L.append(f"| Mean range width (% of midpoint) | {_n(summary.mean_range_width_pct)} |")
    L.append("")
    L.append(
        "*Read together.* Coverage alone is gameable — a 100–2000 kcal range covers "
        "everything and says nothing."
    )
    L.append("")

    L.append("## Confidence calibration")
    L.append("")
    L.append("| Stated confidence | Items | Mean absolute kcal error |")
    L.append("|---|---:|---:|")
    for level in ("high", "medium", "low"):
        L.append(
            f"| {level} | {summary.confidence_counts.get(level, 0)} | "
            f"{_n(summary.confidence_mape.get(level))} |"
        )
    L.append("")
    verdict = {
        True: "✅ Monotonic — confidence predicts error, so the chip is worth showing.",
        False: "❌ Not monotonic — confidence does not predict error. Do not ship the chip as-is.",
        None: "— Not enough data in at least two buckets to judge.",
    }[summary.confidence_monotonic]
    L.append(verdict)
    L.append("")

    if summary.n_runs > 1:
        L.append("## Run-to-run variance (identical images)")
        L.append("")
        L.append(f"- Mean coefficient of variation: {_n(summary.mean_run_cv)}")
        L.append(f"- Worst case: {_n(summary.max_run_cv)}")
        L.append("")

    L.append("## Cost and latency")
    L.append("")
    L.append("| Metric | Value |")
    L.append("|---|---:|")
    L.append(f"| Total cost | ${summary.total_cost_usd:.4f} |")
    calls = summary.n_meals * max(1, summary.n_runs)
    L.append(f"| Cost per image | ${summary.total_cost_usd / calls:.4f} |" if calls else "| Cost per image | — |")
    L.append(f"| Projected 1,800 calls/month (§10) | ${summary.total_cost_usd / calls * 1800:.2f} |" if calls else "| Projected | — |")
    L.append(f"| Mean latency | {_n(summary.mean_latency_ms, ' ms', 0)} |")
    L.append(f"| p90 latency | {_n(summary.p90_latency_ms, ' ms', 0)} |")
    L.append(f"| Input tokens | {summary.total_input_tokens:,} |")
    L.append(f"| Output tokens | {summary.total_output_tokens:,} |")
    L.append(f"| Served from prompt cache | {summary.cache_read_tokens:,} |")
    L.append("")

    if worst:
        L.append("## Worst five meals")
        L.append("")
        L.append("| Photo | Actual kcal | Predicted | Error |")
        L.append("|---|---:|---:|---:|")
        for meal in worst[:5]:
            L.append(
                f"| `{meal.photo_id}` | {meal.actual_kcal:.0f} | "
                f"{meal.predicted_kcal:.0f} | {meal.signed_pct:+.1f}% |"
            )
        L.append("")
        L.append(
            "*Look at these photos.* A pattern here (all soups? all mixed dishes? all "
            "poor lighting?) is a prompt improvement, and it is the kind of specific "
            "finding that makes the write-up concrete."
        )
        L.append("")

    L.append("## Next")
    L.append("")
    L.append(
        "- Sweep `--max-edge 2576 1568 1024 768` to test §1.3's claim that accuracy "
        "barely moves with downscaling. If it holds, that is a measured ~4× image-token "
        "saving for the write-up."
    )
    L.append(
        "- Sweep `--model` across `gemini-3.5-flash-lite` and `gemini-3.6-flash` for the "
        "cost/accuracy curve. Add `--provider anthropic --model claude-opus-5` for a "
        "cross-provider arm if you put credit there."
    )
    L.append(
        "- `--effort` is an ANTHROPIC-only lever and is ignored on Gemini. Skip that "
        "sweep unless you switch provider."
    )
    L.append(
        "- Record the final numbers in `docs/phase-0/07-spike-findings.md`. §0.7 is "
        "right that the number is the asset — but only if it is written down."
    )
    L.append("")

    return "\n".join(L)
