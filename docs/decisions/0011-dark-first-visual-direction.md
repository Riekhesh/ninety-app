# ADR 0011 — Quiet premium, dark-first visual direction

**Status:** Locked
**Date:** 2026-07-30
**Phase:** 0
**Brief reference:** §0.5, §10

## Context

§0.5 requires a token system and one high-fidelity hero screen (the rank screen) but does not
specify a visual direction. Four were considered: quiet premium dark-first, warm clinical
light, bold gamified, and editorial data-forward.

## Decision

**Quiet premium, dark-first.** Near-black canvas, restrained cool accent, and — the load-bearing
part — **the tier metals are the only saturated colour in the entire product.**

Light mode is built to full parity from day one, not retrofitted.

## Reasoning

**It gives the differentiator a colour budget.** The weekly rank-up is the core retention
moment (§2.2). If the rest of the app is chromatically quiet, the tier reveal is loud without
needing animation or confetti to carry it. Saturated colour is *rationed* to the one screen
that matters. That is a design system doing structural work, not decoration.

**Restraint reads as trustworthy for health data.** The audience is people who have bounced off
gym-bro aesthetics before.

**It is the direction most compatible with §10.** Bold gamified was the tempting alternative
and was rejected on safety grounds: streak drama and "no punishment framing" are in direct
tension, and gamifying calorie restriction is precisely the documented harm §10 warns about.
Choosing a calm visual language means the safety requirements and the aesthetic pull the same
way instead of fighting.

## One deliberate deviation from the chosen swatch

The direction as picked specified a neutral-cool neutral ramp (`#0B0B0D` / `#16161A`) and
flagged the risk that dark-only "can feel clinical-cold."

**Resolution: the neutral ramp is warm-shifted graphite** (hue ≈ 30°, very low saturation) —
`#0C0B0A` canvas, `#171614` surface, `#F6F4F1` text — while the cool accent `#7C9EFF` is kept
exactly as chosen. A cool accent on warm ground is a deliberate tension, and it means the
warmth comes from the neutrals rather than from adding a second saturated colour that would
compete with the tier metals.

This is one token-file edit to reverse. The cool ramp is preserved as a commented variant in
`design/tokens/ninety.tokens.json` if the warmth turns out to be wrong on a real device.

## Trade-off accepted

Dark-first means light mode is the second-class citizen in practice, however carefully the
tokens are defined — it will get less real-device testing. Mitigation: the design system page
renders both, and the Phase 1 PR template asks for it.

Rationing saturated colour to the tier badges means the rest of the app has fewer tools for
drawing attention. It has to lean on type scale, weight, and spacing instead. That is more
design discipline, not less.

## Reversal trigger

Phase 3 feedback showing users cannot find things (a navigation or affordance problem traceable
to insufficient colour contrast between interactive and static elements), or accessibility
testing failing WCAG AA on a surface the tokens claim to cover.

"I got bored of it in week six" is not a trigger.

---

## Reversed in part — 2026-08-30: the direction is Matchday, not quiet premium

**What new information changed it.** Not a metric — a design round with real screens
in front of us. Three directions were built at full fidelity and compared
(`design/redesign/`); the developer's verdict on the two that stayed inside the
original "quiet premium" register was that they read as generated. The third,
committed to a single strong world, did not. That is evidence this ADR could not have
had at the time: it was written before any screen existed to react to.

**What is reversed:** *quiet premium*. Matchday is a committed world, not a restrained
one — a lit pitch with mown stripes, chalk lines at 2px, a floodlight, and gold used
at page scale for the division. The original decision's instinct that restraint reads
as premium is not wrong in general; it was wrong for a product whose entire thesis is
a **rank**, where the weekly result has to feel like a result.

**What is unchanged, and is most of this ADR:**

- **Dark-first**, for the reasons already recorded here. Light is full parity.
- **The colour budget.** One accent, reserved. Matchday spends it harder than the
  original palette did, but on one thing — the division — and nothing else.
- **No error colour for logged intake.** Still absent from the token set by design.
- **Tier never carried by colour alone** ([ADR 0012](0012-tier-carried-by-count-not-colour.md))
  — the notch count became a chevron count; the constraint is untouched.
- The WCAG AA validator in `generate.py` still gates every pair, and passed the whole
  Matchday palette without a threshold being lowered.

**Reversal trigger for the new direction:** Phase 3 testers who do not follow football
find the metaphor alienating or confusing rather than incidental — measured by whether
they can say what a "division" is after a week. Record the answers, not the impression.
