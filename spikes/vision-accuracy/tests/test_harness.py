"""Self-test for the accuracy harness.

Runs in CI with no API key, no network and no cost, using the deterministic mock
provider. The point is narrow but important: **prove the downscale → call → score →
report pipeline is intact**, so that a real run against 20 weighed meals — which you
only get to do once, and which costs money — cannot fail on plumbing.

These tests do NOT validate model accuracy. That is what the real run measures.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest
from PIL import Image

SPIKE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SPIKE))

from notchvision import imaging, metrics  # noqa: E402
from notchvision.dataset import GroundTruthError, load_truth  # noqa: E402
from notchvision.env import find_dotenv, load_dotenv, parse_dotenv  # noqa: E402
from notchvision.providers import MockProvider, UnpricedModelError, Usage  # noqa: E402
from notchvision.report import render  # noqa: E402
from notchvision.schema import EstimateParseError, parse_estimate  # noqa: E402


# ─── Fixtures ────────────────────────────────────────────────────────────────


def make_photo(path: Path, size: tuple[int, int], seed: int = 0) -> Path:
    """A deterministic non-uniform image (uniform images compress suspiciously well)."""
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            px[x, y] = ((x * 7 + seed) % 256, (y * 11 + seed) % 256, (x + y + seed) % 256)
    img.save(path, format="JPEG", quality=92)
    return path


@pytest.fixture
def photo_dir(tmp_path: Path) -> Path:
    d = tmp_path / "photos"
    d.mkdir()
    for i in range(1, 4):
        make_photo(d / f"meal-{i:03d}.jpg", (1800, 1200), seed=i * 40)
    return d


@pytest.fixture
def truth_csv(tmp_path: Path) -> Path:
    p = tmp_path / "groundtruth.csv"
    p.write_text(
        "photo_id,item_name,actual_grams,actual_kcal,notes\n"
        "meal-001,porridge with milk,250,320,\n"
        "meal-002,chicken and rice,340,506,\n"
        "meal-002,banana,118,105,\n"
        "meal-003,porridge with milk,200,256,\n"
    )
    return p


# ─── Imaging ─────────────────────────────────────────────────────────────────


def test_downscales_to_max_edge(tmp_path: Path):
    src = make_photo(tmp_path / "big.jpg", (3000, 2000))
    out = imaging.prepare(src, max_edge=1024)
    assert max(out.width, out.height) == 1024
    assert out.width == 1024 and out.height == 683  # aspect preserved
    assert out.bytes_out < out.bytes_in


def test_never_upscales(tmp_path: Path):
    src = make_photo(tmp_path / "small.jpg", (600, 400))
    out = imaging.prepare(src, max_edge=1024)
    assert (out.width, out.height) == (600, 400)


def test_rejects_edge_above_api_ceiling(tmp_path: Path):
    src = make_photo(tmp_path / "x.jpg", (400, 400))
    with pytest.raises(ValueError, match="ceiling"):
        imaging.prepare(src, max_edge=imaging.MAX_SUPPORTED_EDGE + 1)


def test_hash_is_stable_and_size_dependent(tmp_path: Path):
    src = make_photo(tmp_path / "x.jpg", (2000, 1500))
    a = imaging.prepare(src, max_edge=1024)
    b = imaging.prepare(src, max_edge=1024)
    c = imaging.prepare(src, max_edge=768)
    assert a.sha256 == b.sha256, "same input + same size must cache-hit"
    assert a.sha256 != c.sha256, "different size must NOT reuse a cached response"


def test_image_token_estimate_is_capped(tmp_path: Path):
    src = make_photo(tmp_path / "x.jpg", (2576, 2576))
    out = imaging.prepare(src, max_edge=2576)
    assert out.estimated_image_tokens == 4784


def test_cache_key_includes_prompt_and_model(tmp_path: Path):
    cache = imaging.ResponseCache(tmp_path / "c")
    cache.put("sha", "model-a", "v1", "medium", {"x": 1})
    assert cache.get("sha", "model-a", "v1", "medium") == {"x": 1}
    assert cache.get("sha", "model-b", "v1", "medium") is None, "model must be in the key"
    assert cache.get("sha", "model-a", "v2", "medium") is None, "prompt must be in the key"
    assert cache.get("sha", "model-a", "v1", "high") is None, "effort must be in the key"


# ─── Schema parsing ──────────────────────────────────────────────────────────


def test_repairs_inverted_range_rather_than_failing():
    est = parse_estimate(
        {
            "items": [
                {
                    "name": "rice",
                    "grams_low": 300, "grams_high": 200,
                    "kcal_low": 400, "kcal_high": 260,
                    "confidence": "medium",
                }
            ],
            "notes": "",
        }
    )
    item = est.items[0]
    assert (item.grams_low, item.grams_high) == (200, 300)
    assert (item.kcal_low, item.kcal_high) == (260, 400)
    assert len(est.warnings) == 2


def test_unknown_confidence_degrades_to_medium():
    est = parse_estimate(
        {"items": [{"name": "x", "grams_low": 1, "grams_high": 2,
                    "kcal_low": 1, "kcal_high": 2, "confidence": "certain"}],
         "notes": ""}
    )
    assert est.items[0].confidence == "medium"
    assert any("certain" in w for w in est.warnings)


def test_missing_items_key_is_an_error():
    with pytest.raises(EstimateParseError):
        parse_estimate({"notes": "nothing"})


def test_range_width_and_coverage():
    est = parse_estimate(
        {"items": [{"name": "x", "grams_low": 90, "grams_high": 110,
                    "kcal_low": 180, "kcal_high": 220, "confidence": "high"}],
         "notes": ""}
    )
    item = est.items[0]
    assert item.kcal_mid == 200
    assert item.kcal_range_width_pct == pytest.approx(20.0)
    assert item.covers(190) and not item.covers(250)


# ─── Metrics ─────────────────────────────────────────────────────────────────


def _meal(pid: str, actual: float, predicted: float, run: int = 0):
    return metrics.MealResult(photo_id=pid, run=run,
                              actual_kcal=actual, predicted_kcal=predicted)


def test_bias_and_noise_are_computed_separately():
    # Two meals, both +20% — pure bias, zero noise.
    s = metrics.summarise([_meal("a", 100, 120), _meal("b", 200, 240)], [])
    assert s.bias == pytest.approx(20.0)
    assert s.noise == pytest.approx(0.0)
    assert s.mape == pytest.approx(20.0)


def test_bias_correction_eliminates_pure_systematic_error():
    """§1.3's claim, as a test.

    A model that is uniformly +25% is trivially correctable and harmless to a trend.
    Bias-corrected MAPE should collapse to ~0.
    """
    meals = [_meal(f"m{i}", 100 * (i + 1), 125 * (i + 1)) for i in range(5)]
    s = metrics.summarise(meals, [])
    assert s.mape == pytest.approx(25.0)
    assert s.bias_corrected_mape == pytest.approx(0.0, abs=1e-6)
    assert s.bias_correction_gain == pytest.approx(25.0)


def test_bias_correction_does_not_help_pure_noise():
    """The converse: symmetric random error is NOT correctable.

    Same headline MAPE as the test above, but bias-correction buys nothing — which
    is exactly the distinction the report is built to surface.
    """
    meals = [_meal("a", 100, 125), _meal("b", 100, 75)]
    s = metrics.summarise(meals, [])
    assert s.mape == pytest.approx(25.0)
    assert s.bias == pytest.approx(0.0)
    assert s.bias_corrected_mape == pytest.approx(25.0)
    assert s.bias_correction_gain == pytest.approx(0.0)


def test_within_thresholds():
    meals = [_meal("a", 100, 105), _meal("b", 100, 125), _meal("c", 100, 200)]
    s = metrics.summarise(meals, [])
    assert s.within_10 == pytest.approx(100 / 3)
    assert s.within_30 == pytest.approx(200 / 3)


def test_run_variance_detected_on_repeated_calls():
    meals = [_meal("a", 100, 100, run=0), _meal("a", 100, 150, run=1)]
    s = metrics.summarise(meals, [])
    assert s.mean_run_cv is not None and s.mean_run_cv > 20


def test_item_matching_handles_fuzzy_names_and_misses():
    truth = metrics.TruthMeal("m", (
        metrics.TruthItem("chicken and rice", 340, 506),
        metrics.TruthItem("banana", 118, 105),
    ))
    est = parse_estimate({
        "items": [{"name": "chicken with rice", "grams_low": 300, "grams_high": 400,
                   "kcal_low": 450, "kcal_high": 550, "confidence": "high"}],
        "notes": "",
    })
    pairs, missed, spurious = metrics.match_items(truth, est)
    assert len(pairs) == 1 and pairs[0][0].name == "chicken and rice"
    assert [m.name for m in missed] == ["banana"]
    assert spurious == []


def test_portion_and_density_error_are_separated():
    """Right food, wrong amount: portion error high, density error ~0."""
    truth = metrics.TruthMeal("m", (metrics.TruthItem("rice", 100, 130),))
    est = parse_estimate({
        "items": [{"name": "rice", "grams_low": 150, "grams_high": 150,
                   "kcal_low": 195, "kcal_high": 195, "confidence": "high"}],
        "notes": "",
    })
    _meal_res, items = metrics.score_meal(truth, est, 0)
    s = metrics.summarise([_meal_res], items, n_items_predicted=1)
    assert s.portion_mape == pytest.approx(50.0)
    assert s.density_mape == pytest.approx(0.0, abs=1e-6)


def test_confidence_monotonicity_detection():
    def item(conf, err):
        return metrics.ItemResult("p", "t", "t", conf, 0.0, 0.0, err, True, 20.0)

    good = [item("high", 5), item("medium", 15), item("low", 40)]
    assert metrics.summarise([_meal("a", 100, 100)], good, n_items_predicted=3
                             ).confidence_monotonic is True

    bad = [item("high", 40), item("medium", 15), item("low", 5)]
    assert metrics.summarise([_meal("a", 100, 100)], bad, n_items_predicted=3
                             ).confidence_monotonic is False


# ─── Ground truth loading ────────────────────────────────────────────────────


def test_truth_loads_and_groups_by_photo(truth_csv: Path):
    truth = load_truth(truth_csv)
    assert set(truth) == {"meal-001", "meal-002", "meal-003"}
    assert len(truth["meal-002"].items) == 2
    assert truth["meal-002"].kcal_total == pytest.approx(611)


def test_truth_rejects_missing_columns(tmp_path: Path):
    p = tmp_path / "bad.csv"
    p.write_text("photo_id,item_name\nmeal-001,rice\n")
    with pytest.raises(GroundTruthError, match="missing required column"):
        load_truth(p)


def test_truth_rejects_non_numeric(tmp_path: Path):
    p = tmp_path / "bad.csv"
    p.write_text("photo_id,item_name,actual_grams,actual_kcal\nm,rice,lots,300\n")
    with pytest.raises(GroundTruthError, match="must be numbers"):
        load_truth(p)


def test_truth_skips_comment_rows(tmp_path: Path):
    p = tmp_path / "c.csv"
    p.write_text(
        "photo_id,item_name,actual_grams,actual_kcal\n"
        "# a comment row,,,\n"
        "meal-001,rice,100,130\n"
    )
    assert set(load_truth(p)) == {"meal-001"}


# ─── Provider ────────────────────────────────────────────────────────────────


def test_mock_provider_is_deterministic_and_schema_valid(tmp_path: Path):
    src = make_photo(tmp_path / "m.jpg", (1200, 900), seed=5)
    prepared = imaging.prepare(src, max_edge=1024)
    p = MockProvider()
    a, b = p.estimate(prepared, "medium"), p.estimate(prepared, "medium")
    assert a.raw_json == b.raw_json
    est = parse_estimate(a.raw_json)
    assert est.items and est.warnings == ()


def test_cost_prices_cache_reads_cheaper_than_fresh_input():
    fresh = Usage(input_tokens=10_000, output_tokens=0)
    cached = Usage(cache_read_tokens=10_000, output_tokens=0)
    assert cached.cost_usd("claude-opus-5") < fresh.cost_usd("claude-opus-5") / 5


def test_every_provider_has_a_default_model():
    from notchvision.providers import DEFAULT_MODELS, PROVIDERS

    assert set(DEFAULT_MODELS) == set(PROVIDERS)


def test_unknown_provider_names_the_valid_ones():
    from notchvision import providers

    with pytest.raises(ValueError, match="gemini"):
        providers.build("bard", None)


def test_every_default_model_is_priced():
    """A model with no price used to silently report $0.0000/image, which is worse
    than an error — it looks like the feature is free. The mock is in the table too,
    at a declared zero: "free" and "unknown" must not share a representation."""
    from notchvision.providers import DEFAULT_MODELS, PRICING

    for model in DEFAULT_MODELS.values():
        assert model in PRICING, f"{model} has no pricing entry"


# ─── Unpriced models (NA-14) ─────────────────────────────────────────────────
# The whole point: an unknown cost must never render as $0.00 anywhere between the
# API response and the markdown report.


def test_costing_an_unpriced_model_raises_rather_than_returning_zero():
    usage = Usage(input_tokens=1_636, output_tokens=148)
    with pytest.raises(UnpricedModelError, match="gemini-9.9-imaginary"):
        usage.cost_usd("gemini-9.9-imaginary")


def test_unpriced_error_names_the_file_to_edit():
    """The error is the documentation. It has to say what to add and where."""
    usage = Usage(input_tokens=1)
    try:
        usage.cost_usd("nope-1")
    except UnpricedModelError as exc:
        message = str(exc)
    assert "providers.py" in message and "per million tokens" in message


def test_a_priced_zero_is_still_a_number():
    """The mock costs nothing, and that is a measurement, not a missing one."""
    assert Usage(input_tokens=5_000, output_tokens=500).cost_usd("mock-v1") == 0.0


def test_run_baseline_refuses_an_unpriced_model(photo_dir: Path, truth_csv: Path, capsys):
    import run_baseline

    rc = run_baseline.main([
        "--provider", "mock", "--model", "mock-unpriced",
        "--photos", str(photo_dir), "--truth", str(truth_csv),
        "--tag", "pytest-unpriced", "--no-cache", "--no-analyse",
    ])
    assert rc == 2, "an unpriced model must not produce a run"
    assert not sorted((SPIKE / "runs").glob("*-pytest-unpriced.jsonl"))

    err = capsys.readouterr().err
    assert "refusing to run" in err
    assert "mock-unpriced" in err
    assert "--unpriced-ok" in err, "the refusal must name its own escape hatch"


def test_unpriced_ok_records_null_and_the_report_never_says_zero(
    photo_dir: Path, truth_csv: Path, tmp_path: Path
):
    """The escape hatch collects responses without inventing a price. Everything
    downstream has to carry the unknown through as an unknown."""
    import analyse
    import run_baseline

    rc = run_baseline.main([
        "--provider", "mock", "--model", "mock-unpriced", "--unpriced-ok",
        "--photos", str(photo_dir), "--truth", str(truth_csv),
        "--tag", "pytest-unpriced-ok", "--no-cache", "--no-analyse",
    ])
    assert rc == 0

    run_path = sorted((SPIKE / "runs").glob("*-pytest-unpriced-ok.jsonl"))[-1]
    lines = [json.loads(l) for l in run_path.read_text().splitlines() if l.strip()]
    manifest, records = lines[0], lines[1:]
    assert manifest["priced"] is False
    assert records and all(r["cost_usd"] is None for r in records)
    # Token counts are still real, so the run can be re-costed later from the file.
    assert all(r["usage"]["input_tokens"] > 0 for r in records)

    out_md = tmp_path / "unpriced.md"
    assert analyse.main(["--run", str(run_path), "--truth", str(truth_csv),
                         "--out", str(out_md)]) == 0
    text = out_md.read_text()
    assert "not priced" in text
    assert "$0.0000" not in text, "an unknown cost must never render as a zero one"

    run_path.unlink()


def test_a_partly_unpriced_run_has_no_total(photo_dir: Path, truth_csv: Path):
    """A total that silently omits the unpriced calls reads as the cost of the whole
    run, which is the same lie in a quieter voice."""
    summary = metrics.summarise(
        [metrics.MealResult("m1", 0, 500.0, 550.0)],
        [],
        costs=[0.000862],
        unpriced_calls=1,
    )
    assert summary.total_cost_usd is None
    assert summary.unpriced_calls == 1


# ─── Gemini schema adaptation ────────────────────────────────────────────────
# Gemini's response_schema is an OpenAPI 3.0 subset and REJECTS unknown keys
# rather than ignoring them, so the shared schema has to be adapted. These tests
# are the only way to catch a regression without burning an API call.


def test_gemini_schema_strips_unsupported_keys():
    from notchvision.providers import _to_gemini_schema
    from notchvision.schema import ESTIMATE_SCHEMA

    adapted = json.dumps(_to_gemini_schema(ESTIMATE_SCHEMA))
    assert "additionalProperties" not in adapted
    assert "$schema" not in adapted


def test_gemini_schema_keeps_the_parts_that_matter():
    from notchvision.providers import _to_gemini_schema
    from notchvision.schema import ESTIMATE_SCHEMA

    adapted = _to_gemini_schema(ESTIMATE_SCHEMA)
    item = adapted["properties"]["items"]["items"]

    # The range fields and the confidence enum are the contract — losing any of
    # them silently changes what the model returns.
    for field_name in ("name", "grams_low", "grams_high", "kcal_low", "kcal_high",
                       "confidence"):
        assert field_name in item["properties"], f"lost {field_name}"
    assert item["properties"]["confidence"]["enum"] == ["low", "medium", "high"]
    assert set(item["required"]) == set(item["properties"])


def test_gemini_schema_adds_stable_property_ordering():
    from notchvision.providers import _to_gemini_schema
    from notchvision.schema import ESTIMATE_SCHEMA

    adapted = _to_gemini_schema(ESTIMATE_SCHEMA)
    assert adapted["propertyOrdering"] == ["items", "notes"]
    assert adapted["properties"]["items"]["items"]["propertyOrdering"][0] == "name"


def test_gemini_output_still_parses_with_extra_keys():
    """Losing `additionalProperties: false` means Gemini may add keys we did not
    ask for. That has to be harmless, not a crash."""
    est = parse_estimate({
        "items": [{"name": "rice", "grams_low": 100, "grams_high": 150,
                   "kcal_low": 130, "kcal_high": 195, "confidence": "high",
                   "surprise_field": "gemini added this"}],
        "notes": "",
        "another_surprise": 42,
    })
    assert est.items[0].name == "rice"
    assert est.warnings == ()


# ─── .env loading ────────────────────────────────────────────────────────────
#
# The harness reads keys from os.environ but the key lives in a file. Nothing
# bridged the two, so filling in .env exactly as instructed still produced
# "GEMINI_API_KEY is not set". These lock the bridge in place.


def test_dotenv_parses_comments_exports_and_quotes():
    parsed = parse_dotenv(
        "# a comment\n"
        "\n"
        "GEMINI_API_KEY=abc123\n"
        "export OPENAI_API_KEY=from-export\n"
        'QUOTED="dq"\n'
        "SINGLE='sq'\n"
        "  SPACED = padded \n"
    )
    assert parsed["GEMINI_API_KEY"] == "abc123"
    assert parsed["OPENAI_API_KEY"] == "from-export"
    assert parsed["QUOTED"] == "dq"
    assert parsed["SINGLE"] == "sq"
    assert parsed["SPACED"] == "padded"


def test_dotenv_survives_the_real_env_example(tmp_path: Path):
    """.env.example is full of box-drawing rules and prose. Parsing it must not
    explode or invent keys — it is the literal file the README says to copy."""
    example = SPIKE.parents[1] / ".env.example"
    parsed = parse_dotenv(example.read_text(encoding="utf-8"))
    assert "GEMINI_API_KEY" in parsed
    assert parsed["NOTCH_VISION_MODEL"] == "gemini-3.5-flash-lite"
    assert all(k.replace("_", "").isalnum() for k in parsed)


def test_dotenv_found_by_walking_up_from_a_subdirectory(tmp_path: Path):
    (tmp_path / ".env").write_text("GEMINI_API_KEY=root-key\n", encoding="utf-8")
    deep = tmp_path / "spikes" / "vision-accuracy"
    deep.mkdir(parents=True)
    assert find_dotenv(deep) == tmp_path / ".env"


def test_dotenv_does_not_override_a_real_environment_variable(tmp_path: Path, monkeypatch):
    """An exported key is a deliberate per-run override, and CI injects secrets as
    real variables. A stale .env must never win over either."""
    (tmp_path / ".env").write_text("GEMINI_API_KEY=stale-file-value\n", encoding="utf-8")
    monkeypatch.setenv("GEMINI_API_KEY", "live-exported-value")
    load_dotenv(tmp_path)
    assert os.environ["GEMINI_API_KEY"] == "live-exported-value"


def test_dotenv_ignores_blank_values(tmp_path: Path, monkeypatch):
    """.env.example ships every key blank. A blank must not read as 'set', or the
    failure moves from startup to a confusing auth error at the API."""
    (tmp_path / ".env").write_text("GEMINI_API_KEY=\n", encoding="utf-8")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    load_dotenv(tmp_path)
    assert "GEMINI_API_KEY" not in os.environ


def test_dotenv_sets_the_key_the_provider_actually_looks_for(tmp_path: Path, monkeypatch):
    """The end-to-end claim: a key in .env reaches the provider's os.environ lookup."""
    (tmp_path / ".env").write_text("GEMINI_API_KEY=from-dotenv\n", encoding="utf-8")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    assert load_dotenv(tmp_path) == tmp_path / ".env"
    assert os.environ.get("GEMINI_API_KEY") == "from-dotenv"


def test_a_second_dotenv_shadows_the_first_and_says_so(tmp_path: Path, monkeypatch, capsys):
    """The footgun: a .env in the spike directory silently hides the repo-root one.
    Nearest still wins — but it must not win quietly."""
    root, nested = tmp_path, tmp_path / "spikes" / "vision-accuracy"
    nested.mkdir(parents=True)
    (root / ".env").write_text("GEMINI_API_KEY=from-root\n", encoding="utf-8")
    (nested / ".env").write_text("GEMINI_API_KEY=from-nested\n", encoding="utf-8")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)

    assert load_dotenv(nested) == nested / ".env"
    assert os.environ["GEMINI_API_KEY"] == "from-nested"

    err = capsys.readouterr().err
    assert "2 .env files" in err
    assert "IGNORED" in err, "the shadowed file must be named as having no effect"


def test_one_dotenv_says_nothing(tmp_path: Path, monkeypatch, capsys):
    """The warning must not fire on the normal single-file case."""
    (tmp_path / ".env").write_text("GEMINI_API_KEY=only-one\n", encoding="utf-8")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    load_dotenv(tmp_path)
    assert capsys.readouterr().err == ""


def test_a_nonexistent_start_directory_is_not_an_error(tmp_path: Path):
    """Called before the photo-directory check, so it must never be the thing that
    raises. Returning None and letting the provider report a missing key is the
    correct failure."""
    assert load_dotenv(tmp_path / "nothing" / "here") in (None, find_dotenv(tmp_path))


# ─── End to end ──────────────────────────────────────────────────────────────


def test_full_pipeline_run_then_analyse(photo_dir: Path, truth_csv: Path, tmp_path: Path):
    """The test that actually matters: run → score → report, end to end."""
    import analyse
    import run_baseline

    rc = run_baseline.main([
        "--provider", "mock",
        "--photos", str(photo_dir),
        "--truth", str(truth_csv),
        "--max-edge", "1024",
        "--tag", "pytest",
        "--no-cache",
        "--no-analyse",
    ])
    assert rc == 0

    runs = sorted((SPIKE / "runs").glob("*-pytest.jsonl"))
    assert runs, "run_baseline wrote no run file"
    run_path = runs[-1]

    lines = [json.loads(l) for l in run_path.read_text().splitlines() if l.strip()]
    manifest, records = lines[0], lines[1:]
    assert manifest["kind"] == "manifest"
    assert manifest["provider"] == "mock"
    assert manifest["prompt_hash"] and manifest["max_edge"] == 1024
    assert len(records) == 3

    out_md = tmp_path / "report.md"
    rc = analyse.main(["--run", str(run_path), "--truth", str(truth_csv),
                       "--out", str(out_md)])
    assert rc == 0

    text = out_md.read_text()
    for heading in ("Headline", "Decomposition", "Range honesty",
                    "Confidence calibration", "Cost and latency", "What this says"):
        assert heading in text, f"report is missing the {heading!r} section"
    assert "mock provider" in text.lower(), "report must flag synthetic data loudly"

    run_path.unlink()


def test_analyse_reports_clearly_when_nothing_matches(photo_dir: Path, tmp_path: Path):
    """The most likely real-world mistake: filenames that don't match the CSV."""
    import analyse
    import run_baseline

    wrong = tmp_path / "wrong.csv"
    wrong.write_text(
        "photo_id,item_name,actual_grams,actual_kcal\nnot-a-photo,rice,100,130\n"
    )
    run_baseline.main([
        "--provider", "mock", "--photos", str(photo_dir), "--truth", str(wrong),
        "--tag", "pytest-nomatch", "--no-cache", "--no-analyse",
    ])
    run_path = sorted((SPIKE / "runs").glob("*-pytest-nomatch.jsonl"))[-1]
    assert analyse.main(["--run", str(run_path), "--truth", str(wrong)]) == 1
    run_path.unlink()
