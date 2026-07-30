# Photo estimate — cost check and accuracy benchmark

> **Throwaway code.** §0.7: *"Write it fast, learn what you need, then delete it."*
> The deliverables are the measured numbers, not this harness.

**Two separate jobs with very different urgency** (see
[ADR 0010](../../docs/decisions/0010-anthropic-as-vision-provider.md)):

| | Answers | Needs | Urgency |
|---|---|---|---|
| **1 · Cost check** | What does one photo estimate cost? | **3 photos** | ✅ **Done** — $0.000862/image, $1.55/mo at 1,800 calls. [Numbers](../../docs/phase-0/07-spike-findings.md) |
| **2 · Accuracy benchmark** | How wrong is the estimate? | 20 weighed meals | Whenever. Not a gate. |

Job 2 used to be a Phase 0 gate. It isn't any more, because the photo estimate is
always presented as a helper — ranges, visible uncertainty, one-tap correction — so a
bad number changes how hard the UI leans on correction rather than killing the feature.
Still worth doing: §0.7 is right that *"most student projects cannot answer that
question at all."* It just doesn't block anything.

---

## Step 0 — prove it works, no API key needed

```bash
pip install -r requirements.txt
python3 make_fixtures.py                      # 12 synthetic photos + derived truth
python3 run_baseline.py --provider mock \
    --photos fixtures/synthetic --truth fixtures/groundtruth.csv --repeats 3
```

Runs the whole pipeline — downscale → call → score → report — against a deterministic
mock and prints a real report. No network, no key, no cost. **Do this first**, so a
broken harness gets found now rather than mid-run.

CI runs the same path (`python3 -m pytest tests -q`, 40 tests).

---

## Step 1 — the cost check (3 photos, ~20 minutes)

The number you actually need before handing the app to anyone.

```bash
cp ../../.env.example ../../.env     # fill in GEMINI_API_KEY
mkdir -p photos                       # drop in ANY 3 food photos — no weighing needed
python3 run_baseline.py --limit 3 --no-analyse
```

Ground truth is optional here. Without it you get no accuracy figures, but the run
records real token counts, latency and **cost per image**, which is the point.

Then multiply: §10 estimates **20 users × 3 photos/day ≈ 1,800 calls a month.** That
tells you whether the vision feature costs 50p or £50 a month, which decides whether
the Edge Function's per-user daily cap needs to be generous or strict.

Cheap comparison on the same 3 photos:

```bash
python3 run_baseline.py --limit 3 --model gemini-3.6-flash --tag flash --no-analyse
```

**Gemini is the default** — you already have credit, and ADR 0010's provider interface
makes a swap one flag. `--provider anthropic` / `--provider openai` still work.

If a call fails with *model not found*, pass a current `--model`. Model ids move faster
than this harness does.

---

## Step 2 — the accuracy benchmark (20 meals, whenever)

```bash
cp groundtruth.example.csv groundtruth.csv
# ... 20 weighed meals in photos/, filled into groundtruth.csv ...
python3 run_baseline.py
```

Roughly $0.02–0.10 for 20 images on `gemini-3.5-flash-lite` — trivially inside your existing
credit, with room for the sweeps below.

The **protocol** for collecting those meals is next, and it matters far more than the
harness does.

---

## Protocol — what makes the number defensible

The harness is the easy part. **The baseline is only as good as the ground truth**, and
the ground truth is the bit that takes an evening. Take this seriously or the number
is not worth quoting.

### Collecting the 20 meals

1. **Weigh everything on a scale.** Not "about a cup". If you estimated the truth,
   you are measuring one guess against another and the result means nothing.
2. **Photograph naturally** — how you'd actually use the app. One shot, from where
   you're sitting, in the light that's there. Not styled, not overhead-flat-lay, not
   with a colour reference card. A baseline measured on unrealistically good photos
   is a number that will not survive Phase 3.
3. **Weigh and log the cooking oil and butter separately.** This is the most
   important rule here. §1.3 names invisible fats as the model's main blind spot, so
   omitting them makes the model look better than it is and hides the exact failure
   you are trying to measure. Measure oil into the pan.
4. **Get the energy figures from labels or Open Food Facts / USDA**, for the weight
   you actually weighed. Never from another calorie app's estimate.
5. **Cover the range you'll really log.** Aim for roughly:
   - 5 simple single-item meals (an apple, a yoghurt pot)
   - 5 composite plates (a curry, a roast — where portion is genuinely hard)
   - 3 packaged items with a label (the easy case; establishes a floor)
   - 3 restaurant or takeaway meals (unknown preparation; the hard case)
   - 2 deliberately awkward photos — bad light, a partly-obscured plate
   - 2 with substantial hidden fat (stir-fry, anything shallow-fried)
6. **Name files to match the CSV.** `meal-001.jpg` ↔ `photo_id` `meal-001`.

Your photos and your ground truth are **gitignored** — they are personal health data
under UK GDPR Article 9 (§10). The generated report is committed; the photos are not.

### Sweeps worth running

Each is one command and each produces a real finding.

```bash
# Does downscaling actually cost accuracy? §1.3 asserts it "barely moves".
# Every current vision model accepts well above 1024px, so this is testable
# rather than assumed. Image-token pricing differs per provider — read the
# $/image the run reports rather than reasoning about it.
for edge in 2576 1568 1024 768; do
  python3 run_baseline.py --max-edge $edge --tag "edge-$edge"
done

# Cost/accuracy curve across models.
for m in gemini-3.5-flash-lite gemini-3.6-flash; do
  python3 run_baseline.py --model $m --tag "${m}"
done

# Cross-provider, if you ever add credit elsewhere. Same photos, same truth.
# python3 run_baseline.py --provider anthropic --model claude-opus-5 --tag claude

# Effort is an ANTHROPIC-only lever. Skip this sweep on Gemini.
# for e in low medium high; do
#   python3 run_baseline.py --provider anthropic --effort $e --tag "effort-$e"
# done

# How much does the same photo vary between calls? Sets a floor on how good
# this feature can ever be — prompt tuning cannot fix run-to-run variance.
python3 run_baseline.py --repeats 3 --tag variance

# One table from all of it.
python3 analyse.py --compare runs/*.jsonl
```

---

## What the report tells you that a single MAPE does not

| Metric | Why it is separate |
|---|---|
| **Bias vs noise** | §1.3 argues *"a consistent 20% error still tracks the trend perfectly well."* That is **only true if the error is systematic.** Bias is a constant you can subtract; noise is not. The report computes **bias-corrected MAPE** so you can see how much of the error is which — and therefore whether §1.3's claim holds for your model on your data. |
| **Portion vs energy density** | Wrong about *how much* (grams) and wrong about *what* (kcal/g) are different failures with different fixes. One says improve size referencing; the other says improve food and preparation knowledge. |
| **Coverage AND range width** | Coverage alone is gameable — "100–2000 kcal" covers everything. Reported together so a useless-but-covering range is visible. |
| **Confidence calibration** | §1.3 says show confidence. That is only honest if confidence predicts error. The report checks the ordering is monotonic and says plainly whether the chip should ship. |
| **Run-to-run variance** | If the same photo yields 480 and 720 kcal on two calls, that is worse than bias and unfixable by prompting. |

---

## Files

```
run_baseline.py       collect responses → runs/*.jsonl (manifest + one line per call)
analyse.py            score a run → markdown report; --compare for a sweep table
make_fixtures.py      synthetic photos + derived truth, for the no-key demo
groundtruth.example.csv   copy to groundtruth.csv; rules are in the comments
notchvision/
  schema.py           the structured-output contract Phase 1's Edge Function inherits
  prompts.py          the prompt, versioned + hashed (bump the version when you edit)
  providers.py        gemini | anthropic | openai | mock, one interface (ADR 0010)
  env.py              loads the repo-root .env into os.environ
  imaging.py          downscale, EXIF, hash, response cache (§10 cost controls)
  metrics.py          the scoring — bias/noise, portion/density, calibration
  report.py           markdown with interpretation, not just numbers
  dataset.py          ground-truth CSV and run-file loading
tests/                40 tests, mock provider, run in CI
```

---

## Provider gotchas worth knowing before you start

All three read as mystery bugs rather than API errors. `providers.py` already handles
them; this is so they don't surprise you if you go editing it.

**Gemini (the default)**
- **`response_schema` is an OpenAPI 3.0 subset, not full JSON Schema.**
  `additionalProperties` is *rejected*, not ignored, so the shared schema is adapted by
  `_to_gemini_schema()`. Consequence: Gemini may return keys we didn't ask for.
  `parse_estimate` ignores unknown keys, and a test asserts that stays true.
- A content-policy block gives you **no text and no error** — it shows up in
  `prompt_feedback`. Raised as `VisionRefusal` so a run reports it instead of crashing.

**Anthropic, if you switch**
- **`temperature` is rejected with a 400, not ignored.** The instinct to set
  `temperature=0` for a reproducible baseline is a hard failure. Reproducibility comes
  from pinning the model id and prompt hash, which every run manifest records.
- **Thinking is on by default and thinking blocks come first**, so
  `response.content[0].text` gets you an empty thinking block rather than your JSON.
  Find the text block by type.

---

## When you're done

Write the numbers into
[`docs/phase-0/07-spike-findings.md`](../../docs/phase-0/07-spike-findings.md) —
§0.7's exit criterion is *"photo-accuracy baseline measured across 20 real meals
**and written down**."* A number in a terminal that scrolled away is not a
deliverable.

Then carry exactly four things into Phase 1 and delete the rest:

1. `schema.ESTIMATE_SCHEMA` — the Edge Function's response contract
2. `prompts.SYSTEM_PROMPT` — the prompt that produced the baseline
3. `imaging.prepare` — the downscale + hash logic
4. **the measured bias constant**, if the report says the error is mostly systematic
