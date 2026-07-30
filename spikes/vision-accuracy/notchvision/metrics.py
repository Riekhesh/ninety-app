"""Scoring. The interesting part of the spike.

§0.7 asks for "the error rate". A single MAPE figure is the *least* useful thing
this data can produce, because it conflates errors with completely different
consequences for the product. The metrics below separate them:

**Bias vs noise — the decomposition that matters most.**
§1.3 makes a specific claim: *"for weight loss, a consistent 20% error still tracks
the trend perfectly well. What matters is the direction and the derivative, not the
absolute number."* That claim is only true if the error is **systematic**. A model
that is reliably 20% high is trivially correctable and harmless to a trend. A model
that is 20% high on average by being 60% high and 20% low at random is unusable for
the same headline MAPE.

So we report `bias` (mean *signed* error) and `noise` (standard deviation of signed
error) separately, and then compute **bias-corrected MAPE** — what the error would be
if you simply subtracted the systematic component. If bias-corrected MAPE is much
lower than raw MAPE, §1.3's claim is confirmed *for this model on this data*, and a
one-line calibration constant in the Edge Function is worth real accuracy.

**Identification vs portion.**
Being wrong about *what* the food is and wrong about *how much* of it there is are
different failures with different fixes. Energy density (kcal/g) isolates
identification; grams isolates portion. Knowing which dominates tells you whether to
improve the prompt's food knowledge or its size referencing.

**Confidence calibration.**
§1.3 instructs "show confidence". That is only honest if confidence predicts error.
We bucket error by stated confidence and check the ordering is monotonic. If it is
not, the confidence chip is decoration and should not ship.

**Range coverage AND width, together.**
Coverage alone is gameable — "100–2000 kcal" covers everything. Reported next to
mean range width so a useless-but-covering range is visible.
"""

from __future__ import annotations

import statistics
from dataclasses import dataclass, field
from difflib import SequenceMatcher

from .schema import CONFIDENCE_LEVELS, Confidence, Estimate, PredictedItem

NAME_MATCH_THRESHOLD = 0.60


# ─── Ground truth ────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class TruthItem:
    name: str
    grams: float
    kcal: float

    @property
    def kcal_per_gram(self) -> float | None:
        return self.kcal / self.grams if self.grams > 0 else None


@dataclass(frozen=True, slots=True)
class TruthMeal:
    photo_id: str
    items: tuple[TruthItem, ...]

    @property
    def kcal_total(self) -> float:
        return sum(i.kcal for i in self.items)

    @property
    def grams_total(self) -> float:
        return sum(i.grams for i in self.items)


# ─── Per-meal and per-item results ───────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class MealResult:
    photo_id: str
    run: int
    actual_kcal: float
    predicted_kcal: float

    @property
    def signed_pct(self) -> float:
        """Positive means the model over-estimated."""
        if self.actual_kcal == 0:
            return 0.0
        return (self.predicted_kcal - self.actual_kcal) / self.actual_kcal * 100

    @property
    def abs_pct(self) -> float:
        return abs(self.signed_pct)


@dataclass(frozen=True, slots=True)
class ItemResult:
    photo_id: str
    truth_name: str
    predicted_name: str | None
    confidence: Confidence | None
    portion_signed_pct: float | None
    density_signed_pct: float | None
    kcal_signed_pct: float | None
    covered: bool | None
    range_width_pct: float | None

    @property
    def matched(self) -> bool:
        return self.predicted_name is not None


# ─── Matching ────────────────────────────────────────────────────────────────


def _similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a.lower().strip(), b.lower().strip()).ratio()


def match_items(
    truth: TruthMeal, estimate: Estimate
) -> tuple[list[tuple[TruthItem, PredictedItem]], list[TruthItem], list[PredictedItem]]:
    """Greedily pair truth items to predicted items by name similarity.

    Returns (pairs, missed truth items, spurious predictions). Greedy rather than
    optimal-assignment because meals have 1–4 items and the failure mode of greedy
    at that size is negligible — while a Hungarian-algorithm implementation is a
    dependency and a bug surface for a throwaway spike.
    """
    remaining = list(estimate.items)
    pairs: list[tuple[TruthItem, PredictedItem]] = []
    missed: list[TruthItem] = []

    for t in truth.items:
        if not remaining:
            missed.append(t)
            continue
        best_idx, best_score = -1, 0.0
        for idx, p in enumerate(remaining):
            score = _similarity(t.name, p.name)
            if score > best_score:
                best_idx, best_score = idx, score
        if best_score >= NAME_MATCH_THRESHOLD:
            pairs.append((t, remaining.pop(best_idx)))
        else:
            missed.append(t)

    return pairs, missed, remaining


def _pct(predicted: float, actual: float) -> float | None:
    if actual == 0:
        return None
    return (predicted - actual) / actual * 100


def score_meal(truth: TruthMeal, estimate: Estimate, run: int) -> tuple[MealResult, list[ItemResult]]:
    meal = MealResult(
        photo_id=truth.photo_id,
        run=run,
        actual_kcal=truth.kcal_total,
        predicted_kcal=estimate.kcal_mid_total,
    )

    pairs, missed, _spurious = match_items(truth, estimate)
    items: list[ItemResult] = []

    for t, p in pairs:
        t_density, p_density = t.kcal_per_gram, p.kcal_per_gram
        items.append(
            ItemResult(
                photo_id=truth.photo_id,
                truth_name=t.name,
                predicted_name=p.name,
                confidence=p.confidence,
                portion_signed_pct=_pct(p.grams_mid, t.grams),
                density_signed_pct=(
                    _pct(p_density, t_density)
                    if (t_density is not None and p_density is not None)
                    else None
                ),
                kcal_signed_pct=_pct(p.kcal_mid, t.kcal),
                covered=p.covers(t.kcal),
                range_width_pct=p.kcal_range_width_pct,
            )
        )

    for t in missed:
        items.append(
            ItemResult(
                photo_id=truth.photo_id,
                truth_name=t.name,
                predicted_name=None,
                confidence=None,
                portion_signed_pct=None,
                density_signed_pct=None,
                kcal_signed_pct=None,
                covered=None,
                range_width_pct=None,
            )
        )

    return meal, items


# ─── Aggregates ──────────────────────────────────────────────────────────────


def _mean(xs: list[float]) -> float | None:
    return statistics.fmean(xs) if xs else None


def _stdev(xs: list[float]) -> float | None:
    return statistics.stdev(xs) if len(xs) > 1 else None


def _median(xs: list[float]) -> float | None:
    return statistics.median(xs) if xs else None


@dataclass(slots=True)
class Summary:
    n_meals: int = 0
    n_runs: int = 0
    n_items_truth: int = 0
    n_items_predicted: int = 0

    # Headline meal-total accuracy
    mape: float | None = None
    median_ape: float | None = None
    bias: float | None = None
    noise: float | None = None
    within_10: float | None = None
    within_20: float | None = None
    within_30: float | None = None

    # The §1.3 test
    bias_corrected_mape: float | None = None
    bias_correction_gain: float | None = None

    # Identification vs portion
    item_recall: float | None = None
    item_precision: float | None = None
    portion_mape: float | None = None
    portion_bias: float | None = None
    density_mape: float | None = None
    density_bias: float | None = None

    # Honesty of the stated range
    coverage: float | None = None
    mean_range_width_pct: float | None = None

    # Is the confidence chip worth showing?
    confidence_mape: dict[str, float | None] = field(default_factory=dict)
    confidence_counts: dict[str, int] = field(default_factory=dict)
    confidence_monotonic: bool | None = None

    # Same photo, repeated calls
    mean_run_cv: float | None = None
    max_run_cv: float | None = None

    # Operational
    total_cost_usd: float = 0.0
    mean_latency_ms: float | None = None
    p90_latency_ms: float | None = None
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    cache_read_tokens: int = 0
    parse_warnings: int = 0
    refusals: int = 0


def summarise(
    meals: list[MealResult],
    items: list[ItemResult],
    *,
    n_items_predicted: int = 0,
    costs: list[float] | None = None,
    latencies: list[int] | None = None,
    parse_warnings: int = 0,
    refusals: int = 0,
) -> Summary:
    s = Summary()
    if not meals:
        return s

    s.n_meals = len({m.photo_id for m in meals})
    s.n_runs = len({m.run for m in meals})
    s.n_items_truth = len(items)
    s.n_items_predicted = n_items_predicted
    s.parse_warnings = parse_warnings
    s.refusals = refusals

    signed = [m.signed_pct for m in meals]
    absolute = [m.abs_pct for m in meals]

    s.mape = _mean(absolute)
    s.median_ape = _median(absolute)
    s.bias = _mean(signed)
    s.noise = _stdev(signed)
    n = len(meals)
    s.within_10 = sum(a <= 10 for a in absolute) / n * 100
    s.within_20 = sum(a <= 20 for a in absolute) / n * 100
    s.within_30 = sum(a <= 30 for a in absolute) / n * 100

    # ── The §1.3 test: how much of the error is systematic? ──
    # Divide out the multiplicative bias and re-measure. A large gain means the
    # error is mostly a constant factor, which is exactly the case §1.3 argues is
    # harmless to a trend — and fixable with one calibration constant.
    if s.bias is not None and s.bias != -100:
        factor = 1 + s.bias / 100
        corrected = [
            abs((m.predicted_kcal / factor - m.actual_kcal) / m.actual_kcal * 100)
            for m in meals
            if m.actual_kcal
        ]
        s.bias_corrected_mape = _mean(corrected)
        if s.mape and s.bias_corrected_mape is not None:
            s.bias_correction_gain = s.mape - s.bias_corrected_mape

    # ── Identification vs portion ──
    matched = [i for i in items if i.matched]
    s.item_recall = len(matched) / len(items) * 100 if items else None
    s.item_precision = (
        len(matched) / n_items_predicted * 100 if n_items_predicted else None
    )

    portion = [i.portion_signed_pct for i in matched if i.portion_signed_pct is not None]
    density = [i.density_signed_pct for i in matched if i.density_signed_pct is not None]
    s.portion_mape = _mean([abs(x) for x in portion])
    s.portion_bias = _mean(portion)
    s.density_mape = _mean([abs(x) for x in density])
    s.density_bias = _mean(density)

    # ── Range honesty ──
    covered = [i.covered for i in matched if i.covered is not None]
    s.coverage = sum(covered) / len(covered) * 100 if covered else None
    widths = [i.range_width_pct for i in matched if i.range_width_pct is not None]
    s.mean_range_width_pct = _mean(widths)

    # ── Confidence calibration ──
    for level in CONFIDENCE_LEVELS:
        bucket = [
            abs(i.kcal_signed_pct)
            for i in matched
            if i.confidence == level and i.kcal_signed_pct is not None
        ]
        s.confidence_counts[level] = len(bucket)
        s.confidence_mape[level] = _mean(bucket)

    ordered = [
        s.confidence_mape[level]
        for level in ("high", "medium", "low")
        if s.confidence_mape.get(level) is not None
    ]
    # Error should RISE as confidence falls. Needs at least two populated buckets
    # to mean anything.
    s.confidence_monotonic = (
        all(a <= b for a, b in zip(ordered, ordered[1:])) if len(ordered) >= 2 else None
    )

    # ── Run-to-run variance on the same photo ──
    # If the same image yields 480 kcal and 720 kcal on two calls, that is a bigger
    # problem than bias — it puts a floor under how good the feature can get, and
    # no amount of prompt tuning fixes it.
    by_photo: dict[str, list[float]] = {}
    for m in meals:
        by_photo.setdefault(m.photo_id, []).append(m.predicted_kcal)
    cvs = [
        statistics.stdev(vals) / statistics.fmean(vals) * 100
        for vals in by_photo.values()
        if len(vals) > 1 and statistics.fmean(vals) > 0
    ]
    s.mean_run_cv = _mean(cvs)
    s.max_run_cv = max(cvs) if cvs else None

    # ── Operational ──
    if costs:
        s.total_cost_usd = sum(costs)
    if latencies:
        s.mean_latency_ms = _mean([float(x) for x in latencies])
        ordered_lat = sorted(latencies)
        idx = min(len(ordered_lat) - 1, int(len(ordered_lat) * 0.9))
        s.p90_latency_ms = float(ordered_lat[idx])

    return s
