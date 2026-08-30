# ADR 0013 — State the thesis as "consistency is the rank", not "nobody rewards consistency"

**Status:** Locked
**Date:** 2026-08-30
**Phase:** 0
**Brief reference:** §01, §0.4, §2.2

## Context

§01 and the README both open on the strong form of the claim:

> *Every fitness app compares you to other people.* … The people with the furthest to
> go get the least encouragement, and they quit first.

The Phase 0 competitor teardown went looking for a counter-example and found one.
[Strava Local Legend](https://support.strava.com/en-us/articles/15401751-local-legends)
awards a crown to whoever completes a segment **most often over a rolling 90 days,
regardless of pace** — a consistency ranking a slow beginner can genuinely top. Strava
also scopes segment leaderboards hyper-locally rather than globally, which is the same
"make the reference group winnable" instinct behind the tier ladder.

So the strong form is **false as written**, and it is false in a way that is easy to
check. It is one search away for any interviewer who knows Strava, and getting caught
overclaiming costs more than the claim was ever worth. See
[the thesis check](../phase-0/04-competitor-teardown.md#strava--the-thesis-check).

## Decision

**Narrow the claim, in every place it is stated, to: consistency and improvement are a
side badge wherever they exist today; here they are the rank — and the rank is
normalised for starting point.** Cite Strava as prior art rather than as an absence.

The wording that replaces the strong form:

> Every fitness app ranks you on absolute performance. Consistency, where it is
> rewarded at all, is a side badge next to that leaderboard. Notch makes normalised
> improvement the rank itself, so a 120 kg beginner and a 70 kg regular can be
> compared fairly.

## Reasoning

**What survives the finding is still the whole project.** Local Legend counts raw
frequency on one segment the user chose, is not normalised for starting point, needs no
anti-gaming defences because there is nothing to fake, and sits *next to* a leaderboard
still headlined by absolute speed. Notch ranks improvement rate and consistency across
all logged behaviour, normalised by a DOTS/Wilks-style coefficient (§2.2), with a
calibration window, edit lock, delta cap and z-score flags behind it (§2.3) — and that
score **is** the headline, not a badge beside one.

**Normalisation is the hard part, and nobody has made it the rank.** §01 already
identifies comparing across starting points as the real engineering problem. Frequency
counting is not that problem. The narrowed claim points directly at the part that is
actually hard, which makes it both truer and a better answer under questioning.

**Citing prior art is the stronger move, not the weaker one.** §01 already cites Wilks
and DOTS as precedent for normalisation. Local Legend belongs in the same list. A
thesis that names its closest prior art and says precisely how it differs is much
harder to knock down than one that claims the territory is empty.

## Trade-off accepted

**The pitch loses its most quotable line.** "Every fitness app compares you to other
people" is a better opening sentence than anything that survives this ADR — it is short,
it lands, and it is the version that gets remembered. The replacement needs a clause
about normalisation to be true, and a claim with a clause is a weaker hook. That is the
price, and it is worth paying: the strong version is one Strava user away from
collapsing in the room where it matters most.

**A reviewer may read the narrowing as a retreat.** Mitigated by where it is written
down — this ADR and the teardown both show the claim was tested and narrowed
deliberately in Phase 0, rather than conceded under questioning later.

## What is deliberately still open

**How a bad leaderboard placement actually feels.** Desk research cannot answer it, and
it is the half of §01 that drives churn. Left open for Phase 3's real testers, who
answer it better than one person's Strava post would have. The narrowed claim above
does not depend on it.

## Reversal trigger

- A competitor ships **normalised** improvement as its headline ranking — not frequency,
  not a badge. That would collapse the surviving differentiator, and the response is a
  scope decision, not a wording change.
- Phase 3 testers report that the tier they are shown feels like the same demoralising
  comparison the thesis claims to fix. That would mean the problem is the leaderboard
  form itself rather than what it ranks, and §01's premise needs reopening, not editing.
