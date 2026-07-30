# ADR 0012 — Encode tier as notch count, not colour alone

**Status:** Locked
**Date:** 2026-07-30
**Phase:** 0
**Brief reference:** §0.5, §03 (tier ladder), §10

## Context

The tier ladder is Bronze → Silver → Gold → Platinum → Diamond (§03). The obvious execution is
five metal-coloured badges.

Two problems surfaced while building the token set:

1. **Silver and Platinum are the same colour.** Any honest rendering of "silver" and
   "platinum" as metals produces two light, desaturated, slightly-cool greys. Pushing them
   apart enough to be distinguishable stops them reading as their own names. Diamond has the
   same issue against Platinum.
2. **Colour-only encoding fails for colour-blind users.** Roughly 1 in 12 men have some form
   of colour vision deficiency. A ladder whose only signal is hue is unreadable to them — and
   the tier badge is the product's single most important piece of information.

## Decision

**Tier is encoded in the number of notches cut into the badge, with metal colour as a
secondary, redundant signal.**

```
Bronze    ▍            1 notch
Silver    ▍▍           2 notches
Gold      ▍▍▍          3 notches
Platinum  ▍▍▍▍         4 notches
Diamond   ▍▍▍▍▍        5 notches
```

The badge form is a shield/chevron with N notches cut from its leading edge. Count is legible
at 20pt (tab bar) and at 240pt (hero screen). Screen-reader label states the tier name and the
position: *"Gold. Tier 3 of 5."*

## Reasoning

**It is what the app is called.** A notch is a mark you cut to record progress — a tally. It is
physical, humble, and pre-digital, and it means *"one more than before"* rather than *"a score."*
That is the thesis in a single visual metaphor: you are not being measured against a scale, you
are accumulating marks against your own past. The name stops being arbitrary and starts being
the product's central image.

**It fixes the accessibility problem for free** rather than by adding a workaround. Count is
categorical, ordinal, and colour-independent. Nothing has to be bolted on.

**It makes the ladder legible without a legend.** Five notches is obviously more than three.
"Platinum" is only obviously better than "Gold" if you already know the convention — which
users of other apps do, and beginners largely do not. Given that the entire thesis is about not
demoralising beginners, a ladder that explains itself is the right call.

**It extends coherently.** The same notch language carries the consistency ring: seven notches,
one per day of the week, filled as days are logged. A continuous ring would misrepresent a
discrete measurement — consistency *is* whole days, not a percentage. Using the same primitive
for both means the design system has one idea in it rather than several.

## Trade-off accepted

Five hand-tuned SVG badge forms instead of one shape recoloured five times. Costs perhaps two
hours in Phase 0 and produces five static assets that never change.

The notch count must never contradict the metal colour. They are two encodings of one value, so
they are generated from a single `tier` enum with no way to set them independently.

Diamond at five notches leaves no headroom if a sixth tier is ever added. Accepted:
§02 locks five fixed tiers, and a sixth would be a scoring-design change (ADR 0007), not a
badge change.

## Reversal trigger

Phase 3 user testing showing people misread the count, or cannot tell 4 notches from 5 at tab-bar
size. Test this explicitly in the Phase 3 one-to-one sessions (§3.4) — show the badge and ask
*"what tier is that, and how do you know?"*
