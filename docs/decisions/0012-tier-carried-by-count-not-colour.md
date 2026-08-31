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

---

## Amended — 2026-08-31: the count is chevrons, and the file is renamed

**What new information changed it.** The Matchday redesign replaced the visual world,
and with it the badge: a shield with notches cut into it became **N stacked chevrons**.

**What is unchanged, and is the entire decision:** tier is carried by a **count**, never
by colour alone. The measurement that forced it is if anything worse in the new palette
— silver and gold now differ by **1.09:1**, platinum and diamond by 1.19:1, both far
under any threshold at which colour could be read as the signal. `generate.py` still
prints those ratios on every run as a note rather than a failure, because the count is
what carries the meaning and the colours are decoration.

**Why chevrons are a better execution of the same decision.** Chevrons are rank
insignia in the military, in sport and in scouting, so "more chevrons is higher" needs
no teaching. A notch cut into a shield had to be explained. The decision got easier to
read without changing.

**One thing this amendment removes.** The original recorded that notches were also what
the app was *named* after — a notch being a tally mark, "one more than before". That
tie is gone: the app is now **Ninety** ([ADR 0014](0014-rename-to-ninety.md)). The
naming rationale was always a bonus argument rather than the reason, and the reason —
colour cannot carry this signal — is untouched.

**File renamed** from `0012-tier-encoded-as-notch-count.md` so the name does not
describe an execution the project no longer uses. The number is unchanged; the ADR
index is the stable reference.
