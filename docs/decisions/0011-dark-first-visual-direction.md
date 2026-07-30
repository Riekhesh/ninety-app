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
`design/tokens/notch.tokens.json` if the warmth turns out to be wrong on a real device.

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
