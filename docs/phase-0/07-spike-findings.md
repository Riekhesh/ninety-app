# Spike findings

§0.7 exit criteria require the photo-accuracy baseline to be **measured and written
down**. A number in a terminal that scrolled away is not a deliverable.

Both sections are `TO BE MEASURED` until you run them. `grep -rn "TO BE MEASURED" docs/`
tells you what's outstanding; CI prints it on every push.

---

## Spike A — HealthKit

**Status:** blocked on Apple Developer Program enrolment.
**Run on:** `TO BE MEASURED` (date, device, iOS version)

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

## Spike B — photo estimate accuracy

**Status:** harness ready and self-tested; needs your 20 weighed meals.
**Run on:** `TO BE MEASURED` · model `TO BE MEASURED` · effort `TO BE MEASURED` · `TO BE MEASURED` px

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

**Does downscaling cost accuracy?** §1.3 says it "barely moves"; `claude-opus-5`
accepts up to 2576px, so this is testable.

| Longest edge | MAPE | Image tokens | $/image |
|---:|---:|---:|---:|
| 2576 | `TO BE MEASURED` | | |
| 1568 | | | |
| 1024 | | | |
| 768 | | | |

**Verdict:** `TO BE MEASURED` — if flat, that's a measured ~4× token saving to quote.

**Cost/accuracy across models:**

| Model | MAPE | $/image | Projected £/mo at 1,800 calls |
|---|---:|---:|---:|
| claude-opus-5 | `TO BE MEASURED` | | |
| claude-sonnet-5 | | | |
| claude-haiku-4-5 | | | |

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
