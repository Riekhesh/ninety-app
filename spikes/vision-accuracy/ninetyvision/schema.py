"""Structured-output contract for the photo → food estimate.

This schema is the contract the Phase 1 Edge Function will honour (§1.3), so it is
worth getting right here rather than in the app. Two properties matter:

  · **Ranges, not points.** `grams_low/high` and `kcal_low/high` instead of single
    values. §1.3 is explicit that a single number is not supportable: trained
    dietitians misestimate by 20–30% and vision models do worse. A point estimate
    is a lie the UI then has to render.

  · **Confidence is per item, not per photo.** A plate can contain one obvious
    thing and one ambiguous thing. Per-photo confidence would average that away,
    and the correction UI needs to know *which item* to flag.

Structured outputs constrain the response rather than requesting it, so a malformed
response is impossible rather than merely unlikely. Note the limits: numeric
constraints (`minimum`, `maximum`, `multipleOf`) are NOT supported, so ranges are
validated client-side in `parse_estimate` below.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Literal

Confidence = Literal["low", "medium", "high"]
CONFIDENCE_LEVELS: tuple[Confidence, ...] = ("low", "medium", "high")

# ─── JSON Schema sent to the model ───────────────────────────────────────────

ESTIMATE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "description": (
                "One entry per distinct food visible. Split composite dishes only "
                "when the components are separately identifiable."
            ),
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Short common name, e.g. 'porridge with milk'.",
                    },
                    "grams_low": {
                        "type": "integer",
                        "description": "Low end of the plausible portion weight in grams.",
                    },
                    "grams_high": {
                        "type": "integer",
                        "description": "High end of the plausible portion weight in grams.",
                    },
                    "kcal_low": {
                        "type": "integer",
                        "description": "Low end of plausible energy, consistent with grams_low.",
                    },
                    "kcal_high": {
                        "type": "integer",
                        "description": "High end of plausible energy, consistent with grams_high.",
                    },
                    "confidence": {
                        "type": "string",
                        "enum": list(CONFIDENCE_LEVELS),
                        "description": (
                            "high: clearly identifiable and portion judgeable against a "
                            "reference. medium: identifiable, portion uncertain. "
                            "low: identity or preparation genuinely ambiguous."
                        ),
                    },
                },
                "required": [
                    "name",
                    "grams_low",
                    "grams_high",
                    "kcal_low",
                    "kcal_high",
                    "confidence",
                ],
                "additionalProperties": False,
            },
        },
        "notes": {
            "type": "string",
            "description": (
                "What could not be determined from the photo — hidden oil, unseen "
                "sugar, obscured portions. Empty string if nothing to flag."
            ),
        },
    },
    "required": ["items", "notes"],
    "additionalProperties": False,
}


# ─── Parsed representation ───────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class PredictedItem:
    name: str
    grams_low: float
    grams_high: float
    kcal_low: float
    kcal_high: float
    confidence: Confidence

    @property
    def grams_mid(self) -> float:
        return (self.grams_low + self.grams_high) / 2

    @property
    def kcal_mid(self) -> float:
        return (self.kcal_low + self.kcal_high) / 2

    @property
    def kcal_range_width_pct(self) -> float:
        """Range width as a percentage of the midpoint.

        A range wide enough to always contain the truth is not informative. Paired
        with coverage in `metrics.py`, this is what stops "just say 100–2000 kcal"
        from scoring well.
        """
        if self.kcal_mid == 0:
            return 0.0
        return (self.kcal_high - self.kcal_low) / self.kcal_mid * 100

    def covers(self, actual_kcal: float) -> bool:
        return self.kcal_low <= actual_kcal <= self.kcal_high

    @property
    def kcal_per_gram(self) -> float | None:
        """Energy density — the part that reflects *identification* rather than portion."""
        return self.kcal_mid / self.grams_mid if self.grams_mid > 0 else None


@dataclass(frozen=True, slots=True)
class Estimate:
    items: tuple[PredictedItem, ...]
    notes: str = ""
    warnings: tuple[str, ...] = field(default=())

    @property
    def kcal_mid_total(self) -> float:
        return sum(i.kcal_mid for i in self.items)

    @property
    def grams_mid_total(self) -> float:
        return sum(i.grams_mid for i in self.items)


class EstimateParseError(ValueError):
    """The model returned JSON that satisfies the schema but is not usable."""


def parse_estimate(raw: str | dict[str, Any]) -> Estimate:
    """Parse and sanity-check a model response.

    Structured outputs guarantee the *shape*; they cannot guarantee the *sense*.
    Numeric constraints are unsupported in the schema, so low > high and negative
    values have to be caught here. Rather than rejecting the whole estimate — which
    would throw away 4 good items because of 1 bad one — implausible values are
    repaired and recorded in `warnings`, and the warning count is reported in the
    baseline. A model that needs frequent repair is telling you something.
    """
    data = json.loads(raw) if isinstance(raw, str) else raw
    if not isinstance(data, dict) or "items" not in data:
        raise EstimateParseError(f"no 'items' key in response: {str(data)[:200]}")

    items: list[PredictedItem] = []
    warnings: list[str] = []

    for idx, entry in enumerate(data["items"]):
        try:
            name = str(entry["name"]).strip()
            g_lo, g_hi = float(entry["grams_low"]), float(entry["grams_high"])
            k_lo, k_hi = float(entry["kcal_low"]), float(entry["kcal_high"])
            conf = str(entry["confidence"]).lower()
        except (KeyError, TypeError, ValueError) as exc:
            raise EstimateParseError(f"item {idx} malformed: {exc}") from exc

        if not name:
            warnings.append(f"item {idx}: empty name")
            name = "unnamed"
        if g_lo > g_hi:
            warnings.append(f"item {idx} ({name}): grams range inverted, swapped")
            g_lo, g_hi = g_hi, g_lo
        if k_lo > k_hi:
            warnings.append(f"item {idx} ({name}): kcal range inverted, swapped")
            k_lo, k_hi = k_hi, k_lo
        if g_lo < 0 or k_lo < 0:
            warnings.append(f"item {idx} ({name}): negative bound clamped to 0")
            g_lo, k_lo = max(0.0, g_lo), max(0.0, k_lo)
        if conf not in CONFIDENCE_LEVELS:
            warnings.append(f"item {idx} ({name}): unknown confidence {conf!r} → medium")
            conf = "medium"

        items.append(
            PredictedItem(
                name=name,
                grams_low=g_lo,
                grams_high=g_hi,
                kcal_low=k_lo,
                kcal_high=k_hi,
                confidence=conf,  # type: ignore[arg-type]
            )
        )

    return Estimate(
        items=tuple(items),
        notes=str(data.get("notes", "")),
        warnings=tuple(warnings),
    )
