# Spike findings

§0.7 exit criteria require the photo-accuracy baseline to be **measured and written
down**. A number in a terminal that scrolled away is not a deliverable.

Both sections are `TO BE MEASURED` until you run them. `grep -rn "TO BE MEASURED" docs/`
tells you what's outstanding; CI prints it on every push.

---

## Spike A — HealthKit — **MEASURED** ✅

**Status:** **passed.** The exit criterion — *"your own real step and weight history
rendering on your own iPhone"* — is met.
**Run on:** 2026-08-31, physical iPhone, iOS 26.6.1, Xcode 26.6 (17F113), deployment
target iOS 18.0.

### Did it work

| | |
|---|---|
| Authorisation sheet appeared | Yes. All types granted on the first run |
| Days of step data returned | **31** · mean 3,588.5 steps/day |
| Days of weight data returned | 1 (only same-day entries existed to read) |
| Active energy | 22 days · mean 259.8 kcal |
| Exercise minutes | 21 days · mean 24.5 min |
| Workouts | 40 samples read — see the empty-state bug below |

**The project's one genuinely fatal unknown is closed.** HealthKit hands over weight
and steps on a real device, through the modern async API, at a usable speed.

### The anchor test — the performance finding

| | Samples reported |
|---|---:|
| First read (no anchor) | **56,764** (steps) |
| Second read (anchor saved) | **0** |
| After force-quit and relaunch | ~0 — the anchor survived the launch |
| After resetting anchors | back to the full count |

§1.4 calls the persisted anchor *"the entire trick"*, and the gap above is what that
means: **56,764 → 0**. Without it, every cold launch re-reads the lot.

### The finding nobody wrote down in advance: samples are not days

| Type | Raw samples | Days of data | Samples per day |
|---|---:|---:|---:|
| Steps | 56,764 | 31 | **~1,830** |
| Active energy | 66,165 | 22 | **~3,000** |
| Exercise minutes | 1,089 | 21 | ~52 |

HealthKit does not store *"3,917 steps on Sunday"*. It stores hundreds of small
increments per day, per source — phone and watch both writing continuously.

**The Phase 1 consequence, and it is a hard rule:** never iterate raw samples to build
a daily total. `HKStatisticsCollectionQuery` buckets inside HealthKit and returns 31
values instead of 56,764 objects. The spike used it and returned promptly; the naive
version would have the Today screen chewing through ~123,000 objects on every launch.
This is the measured reason the architecture is right, rather than an assumption that
it is.

### The denied-read test

Steps turned off in Settings → Health → Data Access & Devices, then read again.

**What came back:** an empty result. No error, no exception, no signal of any kind
that a permission was refused.

**Distinguishable from "no data"?** **No** — exactly as §0.7 predicted. iOS withholds
this deliberately: knowing a user hid a data type is itself information about them,
so there is no read-permission API and there will not be one.
`authorizationStatus(for:)` reports **write** permission only, and using it to infer
read access is a trap.

**The design consequence, which is the actual deliverable of this spike:** there is no
permission-denied branch to write, because the app cannot know. Every data surface
needs a designed empty state, and "no data" and "access declined" must be worded
identically — because they are the same event as far as the code is concerned. This is
principle 5 in the design system and it is now measured rather than assumed.

### Anything surprising

**1. The spike's own empty state was dishonest, and that is a finding.** The workouts
row read **40 samples successfully** and then printed *"no daily values — either there
is nothing recorded, or read access was declined."* Both halves of that sentence were
false: data was read, and nothing was declined. Workouts are not a quantity type, so
they have no daily buckets, and the code fell through to the shared empty-state copy.

Small bug, real lesson: an empty state that guesses at *why* it is empty will
eventually guess wrong in front of a user. Phase 1's version should say what it knows
("no daily totals for this type") and stop there.

**2. The spike code had never been compiled.** Written in Phase 0 with no Apple
Developer account, it produced three errors on its first real build — all from being
written against the older callback-based `HKAnchoredObjectQuery` rather than the async
descriptor: `HKSamplePredicate` is generic and cannot be unified across quantity
samples and workouts, and `result.newAnchor` is non-optional so the `if let` around it
could not bind. Fixed, with comments explaining why, in `HealthSpike.swift`.

Worth noting for Phase 1: every HealthKit tutorial online shows the callback form, and
the difference is invisible until the compiler objects.

**3. Bodyweight read 120.00 kg from a same-day entry**, so the 30-day weight trend had
a single point. Nothing wrong — there was simply no back-history to read. Phase 1's
trend view needs to handle "one data point" as a real state, not just a sparse one.

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

**Status:** harness proven end-to-end against the live API; needs 20 weighed meals.
Not a Phase 0 gate — see [ADR 0010](../decisions/0010-anthropic-as-vision-provider.md).

> **Folded into Phase 1, decided 2026-08-30.** Phase 1's exit criteria already require
> **21 days of logged food**, so a separate 20-meal collection exercise would be
> gathering data that phase produces anyway. The meals come from real use instead.
>
> **The one thing this requires of the Phase 1 build:** the logging flow has to **keep
> the photo** and the confirmed values together, so a run can be scored afterwards.
> Discard the image once the estimate is shown and there are 21 days of logs with
> nothing to score — and the separate exercise is back. Weigh what is easy to weigh as
> you go; a partial ground truth over 21 days beats a perfect one over zero.
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
