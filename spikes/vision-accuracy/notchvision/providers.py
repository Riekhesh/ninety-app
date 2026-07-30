"""Vision providers behind one interface (ADR 0010).

Three implementations:

  · `anthropic` — the default. `claude-opus-5` with structured outputs.
  · `openai`    — so the Phase 0 deliverable can be "here is the measured error rate
                  for N models" rather than "for the one I picked".
  · `mock`      — deterministic, no network, no key. Lets CI prove the whole
                  downscale → call → score → report pipeline works, so a real run
                  against 20 meals cannot fail on plumbing.

Two API details that cost real time if you don't know them, both specific to
`claude-opus-5`:

  1. **`temperature` is rejected, not ignored.** It returns a 400. The instinct to
     "set temperature 0 for a reproducible baseline" is a hard failure. Reproducibility
     comes from pinning the model id and prompt hash — which the manifest does.

  2. **Thinking is on by default and its blocks come first.** Reading
     `response.content[0].text` gets you an empty thinking block, not your JSON. Find
     the text block by type.
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass, field
from typing import Any, Protocol

from .imaging import PreparedImage
from .prompts import SYSTEM_PROMPT, USER_PROMPT
from .schema import ESTIMATE_SCHEMA

# ─── Pricing, USD per million tokens ─────────────────────────────────────────
# Snapshot taken 2026-07-30. Cache writes bill at 1.25× input, cache reads at 0.1×.
# Verify against platform.claude.com/docs/en/pricing before quoting a cost figure
# in the write-up.
PRICING: dict[str, tuple[float, float]] = {
    "claude-opus-5": (5.00, 25.00),
    "claude-opus-4-8": (5.00, 25.00),
    "claude-sonnet-5": (3.00, 15.00),
    "claude-haiku-4-5": (1.00, 5.00),
    # Non-Anthropic rates are approximate and move often. The report prints a
    # $/image figure, so CONFIRM these against the provider's pricing page before
    # quoting a cost in the write-up.
    "gpt-5": (1.25, 10.00),
    "gemini-2.5-flash": (0.30, 2.50),
    "gemini-2.5-pro": (1.25, 10.00),
}
CACHE_WRITE_MULTIPLIER = 1.25
CACHE_READ_MULTIPLIER = 0.10


@dataclass(slots=True)
class Usage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_write_tokens: int = 0
    cache_read_tokens: int = 0

    def cost_usd(self, model: str) -> float:
        rate_in, rate_out = PRICING.get(model, (0.0, 0.0))
        per_token_in = rate_in / 1_000_000
        return (
            self.input_tokens * per_token_in
            + self.cache_write_tokens * per_token_in * CACHE_WRITE_MULTIPLIER
            + self.cache_read_tokens * per_token_in * CACHE_READ_MULTIPLIER
            + self.output_tokens * (rate_out / 1_000_000)
        )


@dataclass(slots=True)
class ProviderResult:
    raw_json: dict[str, Any]
    usage: Usage
    latency_ms: int
    model: str
    stop_reason: str = "end_turn"
    extras: dict[str, Any] = field(default_factory=dict)


class VisionRefusal(RuntimeError):
    """The model's safety classifiers declined the request.

    Returns HTTP 200 with `stop_reason: "refusal"` and an empty or partial content
    array — NOT an exception from the SDK. Code that indexes `content[0]`
    unconditionally breaks here. Food photos should never trigger this; it is caught
    so that if it ever does, the run reports it clearly instead of crashing on an
    index error.
    """


class VisionProvider(Protocol):
    name: str
    model: str

    def estimate(self, image: PreparedImage, effort: str) -> ProviderResult: ...


# ─── Anthropic ───────────────────────────────────────────────────────────────


class AnthropicProvider:
    """Claude with a JSON Schema constraining the response (ADR 0010)."""

    name = "anthropic"

    def __init__(self, model: str = "claude-opus-5", max_tokens: int = 2000) -> None:
        try:
            import anthropic
        except ImportError as exc:  # pragma: no cover - dependency guard
            raise RuntimeError(
                "pip install -r spikes/vision-accuracy/requirements.txt"
            ) from exc

        if not os.environ.get("ANTHROPIC_API_KEY"):
            raise RuntimeError(
                "ANTHROPIC_API_KEY is not set. Copy .env.example to .env and fill it in, "
                "or run with --provider mock to exercise the pipeline without a key."
            )

        self.model = model
        self.max_tokens = max_tokens
        self._client = anthropic.Anthropic()

    def estimate(self, image: PreparedImage, effort: str) -> ProviderResult:
        started = time.perf_counter()

        response = self._client.messages.create(
            model=self.model,
            max_tokens=self.max_tokens,
            # Cached across the run: one write, then reads at ~0.1×. The system
            # prompt is well over the 512-token minimum for this model.
            system=[
                {
                    "type": "text",
                    "text": SYSTEM_PROMPT,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            # `effort` and `format` both live inside output_config, not top level.
            output_config={
                "effort": effort,
                "format": {"type": "json_schema", "schema": ESTIMATE_SCHEMA},
            },
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": image.media_type,
                                "data": image.data_b64,
                            },
                        },
                        {"type": "text", "text": USER_PROMPT},
                    ],
                }
            ],
            # NO temperature — rejected with a 400 on this model.
        )
        latency_ms = int((time.perf_counter() - started) * 1000)

        if response.stop_reason == "refusal":
            detail = getattr(response, "stop_details", None)
            category = getattr(detail, "category", None) if detail else None
            raise VisionRefusal(
                f"declined (category={category}). Content is empty or partial; "
                "there is nothing to parse."
            )

        # Thinking blocks precede the text block on this model — find by type.
        text = next(
            (b.text for b in response.content if getattr(b, "type", None) == "text"),
            None,
        )
        if text is None:
            raise RuntimeError(
                f"no text block in response (stop_reason={response.stop_reason}, "
                f"block types={[getattr(b, 'type', '?') for b in response.content]})"
            )

        u = response.usage
        usage = Usage(
            input_tokens=getattr(u, "input_tokens", 0) or 0,
            output_tokens=getattr(u, "output_tokens", 0) or 0,
            cache_write_tokens=getattr(u, "cache_creation_input_tokens", 0) or 0,
            cache_read_tokens=getattr(u, "cache_read_input_tokens", 0) or 0,
        )

        return ProviderResult(
            raw_json=json.loads(text),
            usage=usage,
            latency_ms=latency_ms,
            model=self.model,
            stop_reason=str(response.stop_reason),
        )


# ─── OpenAI (comparison arm) ─────────────────────────────────────────────────


class OpenAIProvider:
    """Comparison arm. Same schema, same images, same ground truth."""

    name = "openai"

    def __init__(self, model: str = "gpt-5", max_tokens: int = 2000) -> None:
        try:
            from openai import OpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("pip install openai") from exc
        if not os.environ.get("OPENAI_API_KEY"):
            raise RuntimeError("OPENAI_API_KEY is not set")
        self.model = model
        self.max_tokens = max_tokens
        self._client = OpenAI()

    def estimate(self, image: PreparedImage, effort: str) -> ProviderResult:
        started = time.perf_counter()
        response = self._client.chat.completions.create(
            model=self.model,
            max_completion_tokens=self.max_tokens,
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": "meal_estimate",
                    "strict": True,
                    "schema": ESTIMATE_SCHEMA,
                },
            },
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": USER_PROMPT},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{image.media_type};base64,{image.data_b64}"
                            },
                        },
                    ],
                },
            ],
        )
        latency_ms = int((time.perf_counter() - started) * 1000)
        u = response.usage
        return ProviderResult(
            raw_json=json.loads(response.choices[0].message.content or "{}"),
            usage=Usage(
                input_tokens=getattr(u, "prompt_tokens", 0) or 0,
                output_tokens=getattr(u, "completion_tokens", 0) or 0,
            ),
            latency_ms=latency_ms,
            model=self.model,
        )


# ─── Mock ────────────────────────────────────────────────────────────────────


class GeminiProvider:
    """Google Gemini. The first provider actually used, because the credit existed.

    ADR 0010 chose Anthropic as the default and put every provider behind an
    interface so a comparison arm was cheap. This class is that decision paying off:
    adding a third provider is ~60 lines and changes nothing else.

    Two Gemini-specific wrinkles:

      1. **`response_schema` is an OpenAPI 3.0 subset, not full JSON Schema.**
         `additionalProperties` is not supported and is rejected rather than ignored,
         so the shared schema has to be adapted — see `_to_gemini_schema`. Losing
         `additionalProperties: false` means Gemini *may* add keys we did not ask
         for; `parse_estimate` ignores unknown keys, so this is harmless here.

      2. **Token accounting names differ** — `usage_metadata.prompt_token_count`
         rather than `usage.input_tokens`. Image tokens are folded into the prompt
         count, so there is no separate image figure to report.
    """

    name = "gemini"

    def __init__(self, model: str = "gemini-2.5-flash", max_tokens: int = 2000) -> None:
        try:
            from google import genai
        except ImportError as exc:  # pragma: no cover - dependency guard
            raise RuntimeError(
                "pip install google-genai\n"
                "  (the new unified SDK — NOT the older google-generativeai package)"
            ) from exc

        key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if not key:
            raise RuntimeError(
                "GEMINI_API_KEY is not set.\n"
                "  Put it in the repo-root .env (cp .env.example .env) — the run\n"
                "  prints which .env it read, so check that line matches the file\n"
                "  you edited. Or export GEMINI_API_KEY for a one-off run, or use\n"
                "  --provider mock to exercise the pipeline without a key."
            )

        self.model = model
        self.max_tokens = max_tokens
        self._genai = genai
        self._client = genai.Client(api_key=key)

    def estimate(self, image: PreparedImage, effort: str) -> ProviderResult:
        import base64

        from google.genai import types

        started = time.perf_counter()

        response = self._client.models.generate_content(
            model=self.model,
            contents=[
                types.Part.from_bytes(
                    data=base64.standard_b64decode(image.data_b64),
                    mime_type=image.media_type,
                ),
                types.Part.from_text(text=USER_PROMPT),
            ],
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                max_output_tokens=self.max_tokens,
                response_mime_type="application/json",
                response_schema=_to_gemini_schema(ESTIMATE_SCHEMA),
            ),
        )
        latency_ms = int((time.perf_counter() - started) * 1000)

        text = getattr(response, "text", None)
        if not text:
            # Gemini signals a content-policy block via prompt_feedback rather than
            # a stop_reason, and returns no text at all.
            feedback = getattr(response, "prompt_feedback", None)
            raise VisionRefusal(
                f"no text returned (prompt_feedback={feedback}). Food photos should "
                "never trigger this — inspect the image."
            )

        meta = getattr(response, "usage_metadata", None)
        usage = Usage(
            input_tokens=getattr(meta, "prompt_token_count", 0) or 0,
            output_tokens=getattr(meta, "candidates_token_count", 0) or 0,
            cache_read_tokens=getattr(meta, "cached_content_token_count", 0) or 0,
        )

        return ProviderResult(
            raw_json=json.loads(text),
            usage=usage,
            latency_ms=latency_ms,
            model=self.model,
        )


# Keys Gemini's response_schema does not accept. It rejects unknown keys rather
# than ignoring them, so they have to be stripped rather than left in place.
_GEMINI_UNSUPPORTED = {"additionalProperties", "$schema", "default", "examples"}


def _to_gemini_schema(schema: dict[str, Any]) -> dict[str, Any]:
    """Adapt the shared JSON Schema to Gemini's OpenAPI 3.0 subset.

    Recursive, and deliberately conservative: strip what is known-unsupported and
    pass everything else through. `propertyOrdering` is added so the model emits
    fields in a stable order, which makes eyeballing raw responses less painful.
    """
    out: dict[str, Any] = {}
    for key, value in schema.items():
        if key in _GEMINI_UNSUPPORTED:
            continue
        if key == "properties" and isinstance(value, dict):
            out[key] = {k: _to_gemini_schema(v) for k, v in value.items()}
            out["propertyOrdering"] = list(value.keys())
        elif key == "items" and isinstance(value, dict):
            out[key] = _to_gemini_schema(value)
        else:
            out[key] = value
    return out


class MockProvider:
    """Deterministic synthetic estimates. No network, no key, no cost.

    Deliberately built to exhibit the error structure the real thing has, so the
    metrics code is exercised meaningfully rather than fed perfect data:

      · a systematic **+18% bias** (models under-count invisible oil and sugar, so
        they read low on real meals — this fixture inverts high to prove the
        bias-correction maths works in both directions)
      · per-item **noise** that varies with the image hash
      · **confidence that correlates with error**, so calibration analysis has
        something to find
      · one item dropped from multi-item meals, to exercise recall
    """

    name = "mock"

    def __init__(self, model: str = "mock-v1", bias_pct: float = 18.0) -> None:
        self.model = model
        self.bias_pct = bias_pct

    def estimate(self, image: PreparedImage, effort: str) -> ProviderResult:
        seed = int(image.sha256[:8], 16)
        n_items = 1 + (seed % 3)
        noise = ((seed >> 8) % 41 - 20) / 100  # −0.20 .. +0.20

        items = []
        for i in range(n_items):
            base_g = 120 + ((seed >> (4 * i)) % 9) * 30
            density = 0.9 + ((seed >> (3 + i)) % 18) / 10  # kcal per gram
            g = base_g * (1 + self.bias_pct / 100 + noise)
            kcal = g * density
            # Confidence tracks the noise magnitude, so the calibration section of
            # the report has real signal to detect.
            mag = abs(noise)
            conf = "high" if mag < 0.07 else ("medium" if mag < 0.14 else "low")
            spread = 0.18 if conf == "high" else (0.30 if conf == "medium" else 0.45)
            items.append(
                {
                    "name": ["porridge with milk", "chicken and rice", "banana"][i % 3],
                    "grams_low": round(g * (1 - spread / 2)),
                    "grams_high": round(g * (1 + spread / 2)),
                    "kcal_low": round(kcal * (1 - spread / 2)),
                    "kcal_high": round(kcal * (1 + spread / 2)),
                    "confidence": conf,
                }
            )

        return ProviderResult(
            raw_json={"items": items, "notes": "mock provider — no model was called"},
            usage=Usage(
                input_tokens=image.estimated_image_tokens + 700,
                output_tokens=120 * n_items,
            ),
            latency_ms=3,
            model=self.model,
        )


PROVIDERS = ("gemini", "anthropic", "openai", "mock")

DEFAULT_MODELS = {
    "gemini": "gemini-2.5-flash",
    "anthropic": "claude-opus-5",
    "openai": "gpt-5",
    "mock": "mock-v1",
}


def build(provider: str, model: str | None) -> VisionProvider:
    """Factory. `model=None` uses each provider's default (see DEFAULT_MODELS).

    Model ids move faster than this file does. If a call fails with "model not
    found", pass `--model` with a current id rather than assuming the harness is
    broken.
    """
    resolved = model or DEFAULT_MODELS.get(provider)
    match provider:
        case "gemini":
            return GeminiProvider(resolved or "gemini-2.5-flash")
        case "anthropic":
            return AnthropicProvider(resolved or "claude-opus-5")
        case "openai":
            return OpenAIProvider(resolved or "gpt-5")
        case "mock":
            return MockProvider(resolved or "mock-v1")
        case _:
            raise ValueError(
                f"unknown provider {provider!r} — expected one of {', '.join(PROVIDERS)}"
            )
