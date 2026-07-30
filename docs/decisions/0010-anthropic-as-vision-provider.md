# ADR 0010 — A vision provider interface (Gemini first)

**Status:** Amended 2026-07-30 — **Gemini is now the default**, see the amendment at
the bottom. The interface decision below is unchanged and is the part that matters.
**Date:** 2026-07-30
**Phase:** 0
**Brief reference:** §0.2, §04, §1.3

## Context

§0.2 says "Anthropic or OpenAI API — start with $5 of credit." The choice was left open. It
needs settling before Spike B, because the measured baseline error rate is only meaningful
if it is attributable to a **specific model version**.

Requirements for the photo → food path:

1. **Structured output.** The Edge Function must return
   `{items:[{name, estimated_grams, kcal, confidence}]}` reliably. Prompt-and-hope JSON
   parsing fails in production on the day a user photographs something ambiguous.
2. **Good vision on food.** Portion estimation from a single 2D image is the hard part.
3. **Cheap enough at 1,800 calls/month** (§10's estimate for 20 users).
4. **Called from a server, never the client** (§04). Provider choice does not change this.

## Decision

**Anthropic Claude, model `claude-opus-5`, called through a provider interface.**

The spike harness (`spikes/vision-accuracy/`) defines a `VisionProvider` protocol with three
implementations: `anthropic`, `openai`, and `mock`. Every run records the provider, the exact
model id, and a hash of the prompt in its manifest.

## Reasoning

**Structured outputs, not prompt-and-parse.** Claude supports a JSON Schema on
`output_config.format`, which constrains the response shape rather than requesting it. This
is the single most important property for this feature: the Edge Function's contract with the
app is a schema, and it either holds or the request fails loudly.

**The interface costs almost nothing and buys the comparison.** A provider protocol is about
thirty lines. It means the Phase 0 deliverable can be *"here is the measured error rate for
three models"* rather than *"here is the error rate for the one I picked"* — which is a
materially better answer to §0.7's "how accurate is it really?"

**Model choice.** `claude-opus-5` is the default because the baseline should measure the best
available accuracy — that is the number worth quoting, and it sets the ceiling to improve
against. The harness takes `--model`, so measuring cheaper models against the same 20 meals
is one command, and the cost/accuracy curve is a genuinely interesting finding rather than an
assumption.

## Trade-off accepted

Lock-in on structured-output syntax if the provider ever changes. Contained by the interface,
and small: the schema itself is portable.

Opus-tier pricing is higher per call than a small model. Mitigated by §10's controls
(downscale, hash cache, per-user daily cap) and by the fact that Phase 0 is 20 images, not
1,800/month. Revisit at Phase 3 with real usage.

## Two API details that would otherwise have cost an afternoon

Both are recorded here because they are the kind of thing that reads as a mystery bug:

- **`temperature` is rejected on `claude-opus-5`, not ignored.** It returns a 400. Any
  instinct to "set temperature 0 for a reproducible baseline" produces a hard failure. There
  is no sampling-parameter control; reproducibility comes from pinning the model id and the
  prompt hash, which the harness manifest does.
- **Opus 5 accepts images up to 2576px on the long edge** (up to ~4784 image tokens), well
  above the 1024px §1.3 recommends. That makes §1.3's claim — *"downscale to ~1024px, accuracy
  barely moves"* — a **testable hypothesis rather than an assumption.** The harness takes
  `--max-edge`, so the spike measures it. If accuracy really is flat from 2576px down to
  1024px, that is a measured cost saving to put in the write-up. If it is not, the pipeline
  needs to know before Phase 1 builds on it.

## Reversal trigger

- Measured error rate on the 20-meal set is materially worse than the alternative provider
  on the same images. Record both numbers.
- Vision API cost exceeds the §10 projection at Phase 3 volumes, and a cheaper model's
  measured accuracy is acceptable. The whole point of the interface is that this is a
  config change plus a re-run, not a rewrite.

---

## Amended — 2026-07-30: Gemini is the default

**What new information changed it.** The developer already holds ~$10 of Google Gemini
credit and none with Anthropic. Spending $5 to use the *second*-choice provider, when
the provider interface makes swapping a one-flag change, is not a good use of money.

**What changed:** `--provider gemini`, model `gemini-2.5-flash`, is the default.
Anthropic and OpenAI remain available as comparison arms and are one flag away.

**What did not change:** the interface, the schema, the prompt, the metrics, or the
reasoning above for *why* there is an interface. Adding the third provider took ~60
lines and touched nothing else — which is the interface earning its keep rather than a
reversal of the decision.

**Two things this costs, both accepted:**

1. **The headline baseline number will be Gemini's, not Claude's.** Fine — it is still
   a real measurement, and a Gemini-vs-Claude comparison on the same 20 meals is a
   better write-up than one model alone.
2. **Gemini's `response_schema` is an OpenAPI 3.0 subset, not full JSON Schema.**
   `additionalProperties: false` is rejected rather than ignored, so the shared schema
   is adapted by `_to_gemini_schema()` in `providers.py`. The practical consequence is
   that Gemini *may* return keys we did not ask for; `parse_estimate` ignores unknown
   keys, and there is a test asserting that stays true.

The structured-output argument in the reasoning above still holds — Gemini's
`response_schema` constrains the response rather than requesting it, which is the
property that actually mattered.

---

## Amended — 2026-07-30: this is a benchmark, not a spike

**What new information changed it.** A design decision the developer had already made
and I had not accounted for: the photo estimate is **always** presented as a helper,
never as truth — ranges, a visible "this might be wrong", and one-tap correction. It is
never the source of a logged value without confirmation.

That changes what the measurement is *for*:

| | Was framed as | Actually is |
|---|---|---|
| Bad accuracy | could kill the feature | changes the UX weighting, not the feature |
| The 20 meals | a gate before Phase 1 | a portfolio asset, do it any time |
| **Cost per image** | one line in a report | **the only genuine risk here** |

**Consequences:**

- The 20-meal accuracy benchmark is **no longer a Phase 0 exit gate.** It can happen
  during or after Phase 1.
- The **cost check is**, and it needs 3 photos rather than 20. §10's actual warning is
  a surprise bill: *"add the cap before you hand the app to anyone, not after."*
- The accuracy magnitude still feeds design: 15% out means a nudge control is enough;
  60% out with high variance means correction has to be the primary interaction.

**Spike A (HealthKit) remains a genuine spike.** It can still kill the project, and no
amount of good UX rescues an app that cannot read the phone's health data.
