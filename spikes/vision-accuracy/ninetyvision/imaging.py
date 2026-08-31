"""Downscale, hash and cache meal photos.

Three of §10's four cost controls live here (the fourth, a per-user daily cap,
belongs in the Edge Function):

  · **Downscale before upload.** §1.3 says ~1024px on the longest edge, and asserts
    accuracy "barely moves". `--max-edge` makes that a *measurable hypothesis*
    rather than an assumption, because `claude-opus-5` accepts up to 2576px
    (~4784 image tokens vs ~1100 at 1024px). If accuracy really is flat, that is a
    measured 4× saving to put in the write-up. If it is not, Phase 1 needs to know
    before it builds on the assumption.

  · **Cache by image hash.** People photograph the same meal repeatedly. The cache
    key is the hash of the *downscaled bytes* plus the model and prompt version, so
    changing any of those correctly misses.

  · **Report bytes and estimated tokens** so the cost line in the report is real
    rather than a guess.
"""

from __future__ import annotations

import base64
import hashlib
import io
import json
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps

# Anthropic's documented ceiling for high-resolution vision on Opus 5 / Sonnet 5.
# Sending a longer edge than this wastes bytes; the API downsamples anyway.
MAX_SUPPORTED_EDGE = 2576

SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}


@dataclass(frozen=True, slots=True)
class PreparedImage:
    """A photo ready to send, plus everything needed to price and reproduce it."""

    data_b64: str
    media_type: str
    width: int
    height: int
    bytes_out: int
    bytes_in: int
    sha256: str

    @property
    def estimated_image_tokens(self) -> int:
        """Anthropic's documented approximation: (width × height) / 750.

        Capped at the per-image ceiling. An estimate, not a billing figure — the
        report prefers the real `usage` numbers from the API response and falls
        back to this only for the mock provider.
        """
        return min(4784, math.ceil((self.width * self.height) / 750))

    @property
    def shrink_ratio(self) -> float:
        return self.bytes_out / self.bytes_in if self.bytes_in else 1.0


def prepare(path: Path, max_edge: int = 1024, quality: int = 82) -> PreparedImage:
    """Downscale to `max_edge` on the longest side and JPEG-encode.

    Honours EXIF orientation — phone photos are routinely stored rotated with an
    orientation flag, and a sideways plate measurably confuses portion estimation.
    Never upscales: a 600px photo stays 600px.
    """
    if max_edge > MAX_SUPPORTED_EDGE:
        raise ValueError(
            f"max_edge {max_edge} exceeds the {MAX_SUPPORTED_EDGE}px API ceiling"
        )

    raw = path.read_bytes()
    with Image.open(io.BytesIO(raw)) as img:
        img = ImageOps.exif_transpose(img)
        img = img.convert("RGB")

        longest = max(img.size)
        if longest > max_edge:
            scale = max_edge / longest
            new_size = (
                max(1, round(img.width * scale)),
                max(1, round(img.height * scale)),
            )
            img = img.resize(new_size, Image.LANCZOS)

        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality, optimize=True)
        out = buf.getvalue()
        w, h = img.size

    return PreparedImage(
        data_b64=base64.standard_b64encode(out).decode("ascii"),
        media_type="image/jpeg",
        width=w,
        height=h,
        bytes_out=len(out),
        bytes_in=len(raw),
        sha256=hashlib.sha256(out).hexdigest(),
    )


def discover(photo_dir: Path) -> list[Path]:
    """Every supported image in a directory, sorted for stable run ordering."""
    return sorted(
        p
        for p in photo_dir.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_SUFFIXES
    )


# ─── Response cache ──────────────────────────────────────────────────────────


class ResponseCache:
    """Content-addressed cache of model responses.

    Keyed on (image hash, model, prompt version, effort) so that changing the
    prompt or the model correctly misses rather than silently returning a stale
    answer — which would quietly invalidate a measured baseline.

    Deliberately a directory of JSON files rather than a database: the whole point
    of a spike is that you can look at what happened with `cat`.
    """

    def __init__(self, root: Path) -> None:
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)
        self.hits = 0
        self.misses = 0

    def _key(self, image_sha: str, model: str, prompt_version: str, effort: str) -> str:
        digest = hashlib.sha256(
            f"{image_sha}|{model}|{prompt_version}|{effort}".encode()
        ).hexdigest()
        return digest[:32]

    def get(
        self, image_sha: str, model: str, prompt_version: str, effort: str
    ) -> dict | None:
        path = self.root / f"{self._key(image_sha, model, prompt_version, effort)}.json"
        if not path.exists():
            self.misses += 1
            return None
        self.hits += 1
        return json.loads(path.read_text())

    def put(
        self,
        image_sha: str,
        model: str,
        prompt_version: str,
        effort: str,
        payload: dict,
    ) -> None:
        path = self.root / f"{self._key(image_sha, model, prompt_version, effort)}.json"
        path.write_text(json.dumps(payload, indent=2))
