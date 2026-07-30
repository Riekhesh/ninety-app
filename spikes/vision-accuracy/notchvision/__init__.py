"""Spike B — photo-estimate accuracy baseline (§0.7).

THROWAWAY CODE. Optimised for learning speed, not for reuse. Do not import this
from the app. The deliverables are the measured numbers and the schema/prompt design
they validate, not this package.

What is worth carrying into Phase 1:
  · `schema.ESTIMATE_SCHEMA`  — the Edge Function's response contract
  · `prompts.SYSTEM_PROMPT`   — the prompt that produced the baseline
  · `imaging.prepare`         — the downscale + hash logic (§10 cost controls)
  · the measured bias constant, if the baseline shows the error is systematic
"""

__all__ = [
    "dataset",
    "imaging",
    "metrics",
    "prompts",
    "providers",
    "report",
    "schema",
]
