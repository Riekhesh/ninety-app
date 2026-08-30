# Spike findings

§0.7 exit criteria require the photo-accuracy baseline to be **measured and written
down**. A number in a terminal that scrolled away is not a deliverable.

Both sections are `TO BE MEASURED` until you run them. `grep -rn "TO BE MEASURED" docs/`
tells you what's outstanding; CI prints it on every push.

---

## Spike A — HealthKit

**Status:** unblocked pending the ten-minute signing gate — Apple lists HealthKit as a
free-tier capability, so this may never have needed the paid account.
**Run on:** `TO BE MEASURED` (date, device, iOS version)

### The signing gate — run this first

[Procedure](../../spikes/healthkit/README.md#the-ten-minute-gate). Record the result so
it is never re-tested.

| | |
|---|---|
| Free Personal Team signed a HealthKit build | `TO BE MEASURED` (pass / fail) |
| Exact error string, if it failed | `TO BE MEASURED` |
| Xcode version used | `TO BE MEASURED` |

### Did it work

| | |
|---|---|
| Authorisation sheet appeared | `TO BE MEASURED` |
| Days of step data returned | `TO BE MEASURED` |
| Days of weight data returned | `TO BE MEASURED` |
| Active energy | `TO BE MEASURED` |
| Exercise minutes | `TO BE MEASURED` |
| Workouts | `TO BE MEASURED` |

### The anchor test — the performance finding

| | Samples reported |
|---|---:|
| First read (no anchor) | `TO BE MEASURED` |
| Second read (anchor saved) | `TO BE MEASURED` |
| After force-quit and relaunch | `TO BE MEASURED` |
| After resetting anchors | `TO BE MEASURED` |

§1.4 calls the persisted anchor *"the entire trick"*. The gap between the first and
second numbers is what that means in practice.

### The denied-read test

Turn Steps off in Settings → Health → Data Access & Devices, then read again.

**What you got back:** `TO BE MEASURED`

**Was it distinguishable from "no data"?** `TO BE MEASURED` *(expected: no)*

Write down what you actually saw. This is the finding that drives principle 5 in the
design system — every data surface needs a designed empty state, and no-data and
permission-denied have to be worded identically because the app genuinely cannot tell
them apart.

### Anything surprising

`TO BE MEASURED`

---

## Cost per image — **MEASURED** ✅

The Phase 0 gate (see [ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)).
§10's real risk was never accuracy, it was a surprise bill.

**Run on:** 2026-07-30 · `gemini-3.5-flash-lite` · 1024 px · 3 photos, no ground truth

| | |
|---|---:|
| Input tokens per image | 1,636 |
| Output tokens per image | ~148 |
| **Cost per image** | **$0.000862** |
| Projected at §10's 1,800 calls/month | **$1.55** (~£1.23) |
| Latency | 1.9 – 3.1 s per call |

### The finding: §10 overestimated this by more than an order of magnitude

§10 budgeted **$0.01–0.03 per image**, i.e. $18–54/month at 1,800 calls. The measured
figure is **12–35× cheaper**.

| Scenario | Calls/month | Cost |
|---|---:|---:|
| §10's projection — 20 users × 3/day | 1,800 | $1.55 |
| 20 users × 10/day | 6,000 | $5.17 |
| 100 users × 3/day | 9,000 | $7.76 |
| 1,000 users × 3/day | 90,000 | $77.58 |

**Consequence for Phase 1:** the per-user daily cap in the Edge Function is an
**abuse control, not a cost control.** 20–30 photos/day is generous enough that no
honest user reaches it while still bounding a runaway client loop. §10's instruction —
*"add the cap before you hand the app to anyone, not after a surprise bill"* — stands;
the cap just doesn't need to be stingy.

A second consequence: aggressive downscaling is no longer a cost argument. At a tenth
of a penny per image, the `--max-edge` sweep is now an *accuracy* question only.

> Rates are Google's published paid-tier figures for `gemini-3.5-flash-lite`
> ($0.30/$2.50 per 1M in/out), taken from third-party trackers rather than Google's
> pricing page. Confirm before quoting in the write-up. Token counts are measured and
> recorded in the run manifest, so the figure can be recomputed if a rate has moved.

---

## Spike B — photo estimate accuracy

**Status:** harness proven end-to-end against the live API; needs your 20 weighed meals.
Not a Phase 0 gate — see [ADR 0010](../decisions/0010-anthropic-as-vision-provider.md).
**Run on:** `TO BE MEASURED` · model `TO BE MEASURED` · effort `TO BE MEASURED` · `TO BE MEASURED` px

> Informal signal from the 3-photo cost run, **not** a measurement: the estimates were
> broadly plausible against remembered values, and the one large number was a large
> takeaway pizza rather than an error. That is an eyeball check, not a baseline — its
> only value is that the model is not fundamentally broken on real photos from this
> phone, which was genuinely unknown beforehand.

`analyse.py` generates a full report next to each run in
`spikes/vision-accuracy/runs/`. Paste the headline numbers here so they survive.

### Headline

| Metric | Value | |
|---|---:|---|
| Meals | `TO BE MEASURED` | should be 20 |
| **MAPE** | `TO BE MEASURED` | the headline error rate |
| **Bias** (mean signed) | `TO BE MEASURED` | systematic — correctable |
| **Noise** (std dev signed) | `TO BE MEASURED` | random — not correctable |
| Bias-corrected MAPE | `TO BE MEASURED` | error left after removing bias |
| Within 20% | `TO BE MEASURED` | §1.3's stated dietitian tolerance |

### Does §1.3's claim hold?

§1.3 asserts *"a consistent 20% error still tracks the trend perfectly well. What
matters is the direction and the derivative, not the absolute number."*

That is **only true if the error is systematic**. Bias-corrected MAPE is the test.

**Share of total error that is systematic:** `TO BE MEASURED` %

**Verdict:** `TO BE MEASURED`

If most of the error is bias, a single calibration constant in the Edge Function buys
real accuracy and the trend argument is sound. If it's mostly noise, the argument is
weaker than it sounds and the product has to lean harder on the ranges and the
correction UI.

### What kind of wrong is it

| Metric | Value | |
|---|---:|---|
| Item recall | `TO BE MEASURED` | did it find the foods |
| Portion error (grams) | `TO BE MEASURED` | wrong about *how much* |
| Energy-density error (kcal/g) | `TO BE MEASURED` | wrong about *what* |

**Which dominates:** `TO BE MEASURED`

This decides where prompt effort goes and which correction path the UI should make
cheapest.

### Should the confidence chip ship?

| Confidence | Items | Mean error |
|---|---:|---:|
| high | `TO BE MEASURED` | |
| medium | | |
| low | | |

**Monotonic?** `TO BE MEASURED`

§1.3 says show confidence. That's only honest if confidence predicts error. If the
ordering isn't monotonic, the chip is decoration implying a reliability the model
doesn't have — fix the prompt and re-measure, or don't ship it.

### Ranges

| | |
|---|---:|
| Coverage (truth inside range) | `TO BE MEASURED` |
| Mean range width (% of midpoint) | `TO BE MEASURED` |

Read together — coverage alone is gameable, since 100–2000 kcal covers everything.

### Sweeps

**Does downscaling cost accuracy?** §1.3 says it "barely moves", and the harness
accepts up to 2576px, so this is testable rather than assumed.

| Longest edge | MAPE | Image tokens | $/image |
|---:|---:|---:|---:|
| 2576 | `TO BE MEASURED` | | |
| 1568 | | | |
| 1024 | | | 0.000862 |
| 768 | | | |

**Verdict:** `TO BE MEASURED`. Note this is now purely an accuracy question — the cost
check above put 1024px at a tenth of a penny, so there is no meaningful bill to save.

**Cost/accuracy across models:**

| Model | MAPE | $/image | Projected $/mo at 1,800 calls |
|---|---:|---:|---:|
| gemini-3.5-flash-lite | `TO BE MEASURED` | 0.000862 | 1.55 |
| gemini-3.6-flash | | | |
| claude-opus-5 *(optional cross-provider arm)* | | | |

**Run-to-run variance** (same photo, 3 calls): `TO BE MEASURED` % mean CV

If this is high, it puts a floor under how good the feature can ever get — prompt
tuning cannot fix it, and that's worth knowing before Phase 1 builds on it.

### Worst five meals

Look at the photos. A pattern (all soups? all mixed dishes? all poor lighting?) is a
prompt improvement and a specific, concrete finding for the write-up.

`TO BE MEASURED`

### Total spent

`TO BE MEASURED` *(the whole thing should be well under £2)*

---

## The interview answer this produces

§0.7: *"That measured baseline error rate is worth more than the feature itself… a
genuinely impressive answer when someone asks 'but how accurate is it really?' Most
student projects cannot answer that question at all."*

Draft it here once you have the numbers, in two or three sentences. Include the
bias/noise split — that's the part that shows you understood *why* the error rate
matters rather than just measuring one.

`TO BE MEASURED`
