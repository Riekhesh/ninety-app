# Spike B — photo-accuracy baseline

> **Throwaway code.** §0.7: *"Write it fast, learn what you need, then delete it."*
> The deliverable is the measured number, not this harness.

§0.7 says the measured baseline error rate *"is worth more than the feature itself.
It gives you an honest accuracy figure for your write-up, a benchmark to improve
against, and a genuinely impressive answer when someone asks 'but how accurate is it
really?' Most student projects cannot answer that question at all."*

That is the entire point of this directory.

---

## Try it now, with no API key

```bash
pip install -r requirements.txt
python3 make_fixtures.py                      # 12 synthetic photos + derived truth
python3 run_baseline.py --provider mock \
    --photos fixtures/synthetic --truth fixtures/groundtruth.csv --repeats 3
```

That runs the whole pipeline — downscale → call → score → report — against a
deterministic mock, and prints a real report. No network, no key, no cost. Do this
first: it means a broken harness gets found now, rather than halfway through the one
run you make against 20 real meals.

CI runs the same path (`python3 -m pytest tests -q`, 26 tests).

---

## The real thing

```bash
cp ../../.env.example ../../.env      # fill in ANTHROPIC_API_KEY
cp groundtruth.example.csv groundtruth.csv
# ... put 20 weighed meals in photos/ and fill in groundtruth.csv ...
python3 run_baseline.py
```

Roughly $0.15–0.40 for 20 images on `claude-opus-5` at `medium` effort — comfortably
inside §0.2's $5 of credit, with room for the sweeps below.

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
# Does downscaling actually cost accuracy? §1.3 asserts it "barely moves" —
# claude-opus-5 accepts up to 2576px, so this is testable rather than assumed.
for edge in 2576 1568 1024 768; do
  python3 run_baseline.py --max-edge $edge --tag "edge-$edge"
done

# Cost/accuracy curve across models.
for m in claude-opus-5 claude-sonnet-5 claude-haiku-4-5; do
  python3 run_baseline.py --model $m --tag "${m}"
done

# Effort is the primary cost lever, and low/medium are unusually strong here.
for e in low medium high; do
  python3 run_baseline.py --effort $e --tag "effort-$e"
done

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
  providers.py        anthropic | openai | mock, behind one interface (ADR 0010)
  imaging.py          downscale, EXIF, hash, response cache (§10 cost controls)
  metrics.py          the scoring — bias/noise, portion/density, calibration
  report.py           markdown with interpretation, not just numbers
  dataset.py          ground-truth CSV and run-file loading
tests/                26 tests, mock provider, run in CI
```

---

## Two API details worth knowing before you start

Both are `claude-opus-5` specifics that read as mystery bugs:

- **`temperature` is rejected, not ignored** — it returns a 400. The instinct to set
  `temperature=0` for a reproducible baseline is a hard failure. Reproducibility here
  comes from pinning the model id and prompt hash, which every run manifest records.
- **Thinking is on by default and thinking blocks come first** in the response, so
  `response.content[0].text` gets you an empty thinking block rather than your JSON.
  Find the text block by type. `providers.py` does.

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
