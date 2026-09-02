# ADR 0015 — Dynamic Type wins, carried by a bundled face

**Status:** Locked
**Date:** 2026-09-02
**Phase:** 1
**Brief reference:** §1.6, §10
**Supersedes:** nothing. Settles the open question left by the redesign.

## Context

The redesign left exactly one thing unresolved, and it blocked every view
ticket: **fixed type scale or Dynamic Type.**

The six artboards are 393×852 HTML frames with hard-coded point sizes, because a
static frame cannot express Dynamic Type — not because the fixed scale won an
argument. Meanwhile `reference/ios.md` requires system text styles and bans
hard-coded point sizes outright, and the type group in `ninety.tokens.json`
already carries a `ninety.iosTextStyle` on every single style with the note
"non-negotiable for a health app."

So the decision was in practice already made and never written down, which is
the state ADR 0000 exists to prevent.

There is a third thing tangled in it that the framing hid. "Fixed scale vs
Dynamic Type" was being argued as though the alternative to hard-coded sizes was
San Francisco at system text styles. It is not. The artboards are set in **Saira
Condensed** for the broadcast captions and **Saira** for data — that lettering is
a substantial part of what makes Matchday read as a lit pitch rather than a
green SwiftUI app. Neither the tokens nor the generated Swift mentioned a face,
so the generated `font` was `Font.system(...)`: shipping it as-is would have
quietly resolved the open question in favour of *neither* option, by rendering
the whole world in the platform sans.

## Decision

**Dynamic Type, at every type style, with no exceptions — carried by two
bundled faces rather than by San Francisco.**

1. The sizes in `ninety.tokens.json` become the **Large (default) baseline**,
   not a fixed scale. Each style keeps its `ninety.iosTextStyle`, which is the
   ramp it scales along.

2. `generate.py` emits `Font.custom(fontName, size:, relativeTo:)`. The
   `relativeTo:` argument is the entire decision in one parameter:
   `Font.custom(_:size:)` without it does not scale at all, and that failure is
   invisible to anyone whose reading size is Large.

3. **Saira** (data, body, controls) and **Saira Condensed** (mastheads,
   eyebrows, tab labels) are bundled under SIL OFL 1.1, in
   `Ninety/Resources/Fonts`. Weight comes from the *file*, selected at
   generation time — never from a `.weight()` modifier on top, which would make
   iOS synthesise a bolder outline over a weight the family already ships
   properly drawn.

4. **Metric styles may only use Saira.** Saira Condensed has no `tnum` table, so
   `.monospacedDigit()` is a no-op on it and digits would jitter as a value
   updates — the precise thing tabular figures exist to stop.

5. Fixed point sizes remain legal for **drawing**, not for text: the mow-stripe
   width, the chalk line weight, the kit-stripe bar. Those are properties of a
   drawing, and `@ScaledMetric` is used where a drawn element sits beside text
   and must grow with it.

## Why not the fixed scale

It was never really on the table for a health app, and it is worth writing down
why rather than leaving it as taste:

- **The audience.** The core intended user is a beginner with a lot of weight to
  lose (PRODUCT.md). That group skews older than 22 with perfect eyesight, and
  an app whose numbers cannot be enlarged is an app they cannot use.
- **It contradicts work already done.** `generate.py` refuses a colour pair that
  fails WCAG AA. Mechanically enforcing contrast and then hard-coding 11pt type
  would be an accessibility policy that stops precisely where it becomes
  inconvenient.
- **It is a one-way door.** Retrofitting Dynamic Type means revisiting every
  view's layout, because fixed-size layouts are built on assumptions that stop
  holding the moment text can grow. Adopting it now costs the `ViewThatFits` and
  reflow discipline written into `Masthead`; adopting it in Phase 3 costs the
  screens.

## Trade-off accepted

**The artboards are no longer pixel-accurate, and never can be again.** They are
correct at the Large content size and correct nowhere else, which is now a
property of the design rather than a defect in it. A layout that only works at
one reading size is not finished.

Concretely: `metricXL` is 56pt at Large and roughly 98pt at AX5. No layout
survives that unchanged, so every screen holding a metric owes a reflow — the
number wraps, or the row stacks, or the cluster becomes a column. `Masthead`
does this already and is the pattern for the rest.

**Two font families is ~530 KB in the bundle** and one more thing that can break
silently. Accepted, and guarded twice rather than hoped about:

- `check_fonts()` in `generate.py` fails the build if a style names a weight the
  family does not ship, if a metric style is put on the face without `tnum`, or
  if the `.ttf` a token promises is not in the repo.
- `BrandFont.verify()` logs an error at launch if a bundled face did not
  register, because iOS has no error path for this — text simply renders in San
  Francisco and looks fine to anyone who does not know what it should look like.

## Reversal trigger

Reverse to a fixed scale only on evidence that Dynamic Type has broken a screen
in a way reflow cannot fix — a specific screen, at a specific content size, with
the screenshot. Record it here.

Dropping the **bundled faces** back to San Francisco is a smaller, separable
reversal, and there is one trigger worth naming now: if the two families
measurably delay launch or push the bundle somewhere it should not be, drop
Saira Condensed first and set the caption voice in SF Compact with condensed
width. The broadcast lettering is the more expressive half but also the more
replaceable one — the data face is what the user reads all day.

Raising the deployment target is **not** a trigger. `Font.custom(_:size:relativeTo:)`
has been available since iOS 14.

## What this unblocks

Every P1 view ticket. The type tokens are now structurally final, so P1-D
onwards can build screens without the shape of the type scale moving underneath
them.

## Outstanding

The ticket asks for Matchday proven at the smallest and largest accessibility
sizes. Matchday itself is P1-H — there is no dashboard yet to photograph. What
exists now is the mechanism and the harness: every view in the shell ships an
`.accessibility5` preview, and `DesignSystemTests.typeScales` asserts that all
sixteen styles actually respond to the content size category.

**Due with P1-H:** simulator captures of Matchday at `.xSmall` and
`.accessibility5`, both appearances, attached to the P1-H ticket.
