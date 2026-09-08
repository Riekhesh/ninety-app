# ADR 0019 — The 21 days produce a correction dataset, not an accuracy baseline

**Status:** Locked
**Date:** 2026-09-08
**Phase:** 1
**Brief reference:** §1.3, §10 · qualifies [ADR 0010](0010-anthropic-as-vision-provider.md)

## Context

[ADR 0010](0010-anthropic-as-vision-provider.md)'s third amendment folded the
20-meal photo-accuracy benchmark into Phase 1 on one condition: *"that Phase 1's
logging keeps the photo alongside the confirmed values, so the 21 days produce
the dataset instead of a separate evening's collection."* P1-F is where that
condition is implemented, and implementing it surfaced a problem with the
sentence.

`spikes/vision-accuracy/README.md` is emphatic about what its ground truth is:

> `actual_grams` is **WEIGHED** on a scale, not estimated. If you estimated it,
> you are measuring the model against a guess and the baseline is worthless.

A user correcting a portion on Under Review is not weighing it. They are moving
a number until it looks right, from memory and by eye — which is the correct
interaction for the product and is *not* a measurement. So the set the 21 days
produce and the set the benchmark scores are not the same kind of thing, and
running the harness over the first one would produce a number in the harness's
own units that the harness's own rules say is meaningless.

Two smaller shape questions came with it. The `photo_estimates` table holds one
row per `food_logs` row, and a photographed meal is several foods; and the daily
cap §10 asks for has to count something.

## Decision

**Keep the pair, and label it.** The photo, the model's whole output, the
confidence and the confirmed values persist together on every pass — including
the passes where nothing was corrected — and every exported row carries its
provenance in the `notes` column: `user-confirmed on Under Review; NOT weighed`.

**The set measures correction magnitude, and is never reported as the accuracy
baseline.** The 20 weighed meals remain the only thing that produces that
number, and they remain un-run.

Three mechanics follow from it:

- **One `photo_estimates` row per item, not per meal.** The benchmark's ground
  truth is one row per food, so a meal-level delta would not be scoreable
  against it. The storage path and the model output repeat on each row, which
  costs a few kilobytes and makes every row re-scoreable on its own.
- **`was_corrected` and `correction_delta` are written every time.** A dataset
  holding only corrections cannot distinguish *the model was right* from
  *nobody looked*.
- **An item the user adds is recorded as a correction against an estimate of
  zero.** §1.3 names invisible cooking oil and hidden sugar as the failure mode
  that matters most, and a set containing only what the model *did* see cannot
  measure the thing worth measuring.

## Trade-off accepted

**The interesting number stays outstanding.** Nothing here produces "how wrong
is the estimate", and the honest version of this decision is that it makes the
20 weighed meals *more* necessary rather than less — the thing that felt like it
was quietly getting done for free is not getting done.

**A quantity that is easy to misread.** "Median correction of 14%" reads like an
error rate and is not one: a user who corrects nothing has agreed with the model
*or* has not looked, and this set cannot tell those apart at the level of one
row. That is why the provenance is in the file and not only in this document.

**Duplication in the store.** The same `model_output` JSON is written once per
item. A four-item meal stores it four times.

**A cap that can refuse a legitimate request.** The ledger counts requests
rather than confirmations, so an estimate the user abandons still spends a slot,
and a model call that fails after being claimed is not refunded. At thirty a day
nobody logging real meals will notice; the alternative — refunding on error — is
a loop that always errors being refunded forever.

## Reversal trigger

- **The 20 weighed meals are run**, and the correction distribution over the 21
  days turns out to track the measured error closely. At that point the confirmed
  set becomes a usable proxy and can be reported as one — *with* the weighed run
  as the thing that established the relationship.
- **Correction rate is near zero** across a fortnight of real use. That would
  mean the set is recording agreement rather than accuracy and is not worth its
  storage; the honest response is to stop collecting it rather than to keep a
  column nobody can interpret.
- **Storage cost of the repeated `model_output`** becomes measurable against a
  real usage figure, at which point the estimate row splits into a meal-level
  row and per-item children.
