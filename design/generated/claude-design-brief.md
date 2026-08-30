# Paste-into-Claude design brief

**What this is for.** Everything Claude needs to design Notch screens with you in a
chat, in one self-contained block. Paste the section between the two `═══` rules into
a fresh Claude conversation, then ask for whatever screen you want.

It's deliberately compact — the full versions live in `design/spec/` and
`design/tokens/notch.tokens.json`, but you can't paste a 1,400-line HTML file into a
chat window and you shouldn't have to.

**This file is a TEMPLATE. Do not paste from it — the tables are placeholders.**
Paste from `design/generated/claude-design-brief.md`, which `generate.py` writes by
filling those placeholders from the tokens. Edit the prose here; never edit the
generated copy. CI's `--check` fails if the two fall out of step, which is the point:
the brief used to carry hand-copied hex values that were a second source of truth,
and a second source of truth is just a bug with a delay on it.

---

═══════════════════════════ PASTE FROM HERE ═══════════════════════════

I'm designing **Notch**, a native iOS health app (Swift 6.3 / SwiftUI, iOS 18+).

**Thesis:** fitness apps rank you on absolute performance, and where consistency is
rewarded at all it is a side badge next to that leaderboard (Strava's Local Legend is
the closest prior art). Notch makes **normalised** improvement and consistency the rank
itself, so a beginner is compared fairly against their own starting point rather than
buried under people who started years earlier.

Design direction: **quiet premium, dark-first.** Build screens as self-contained HTML
in an iPhone frame (393×852). Use the tokens below and nothing else.

## Colour tokens

Dark is the default. Light is full parity, not an afterthought.

| Token | Dark | Light | Use |
|---|---|---|---|
| canvas | `#0C0B0A` | `#FBFAF7` | App background. Warm near-black. |
| surface | `#171614` | `#FFFFFF` | Cards, rows, sheets. |
| surfaceSunken | `#070606` | `#F2F0EB` | Inset wells: chart backgrounds, input fields. |
| stroke | `#2C2A26` | `#E5E2DB` | Hairline dividers and card edges. |
| strokeStrong | `#3D3A34` | `#CFCBC1` | Input borders, focus-adjacent edges. |
| textPrimary | `#F6F4F1` | `#17150F` | Warm white. 18.4:1 on canvas. |
| textSecondary | `#A8A29A` | `#5C574D` | Supporting copy, units, axis labels. 7.8:1 on canvas — AA at body size. |
| textTertiary | `#8A8479` | `#767063` | Least-emphasis labels. 5.3:1 on canvas, 4.9:1 on surface — AA at body size on both. |
| accent | `#7C9EFF` | `#3B5BDB` | The single accent. Cool blue on warm ground — a deliberate tension. 7.7:1 on canvas. |
| positive | `#4FBF8B` | `#1E8A5F` | Jade. 'Inside your band', 'synced'. |
| safety | `#E2A03F` | `#A66A00` | RESERVED for §10 safety interventions: calorie floor breach, unsafe goal weight, rate-of-loss ceiling. |
| critical | `#E5674E` | `#B4341A` | Destructive confirmation and hard safety blocks ONLY. |
| chartLine | `#F6F4F1` | `#17150F` | The weight trend line (the 7-day EWMA). |
| chartBaseline | `#6E6960` | `#9A9488` | The 'you, four weeks ago' reference line. |
| chartBand | `#1E2A24` | `#E6F2EB` | Target band fill. Wide, soft, unmistakably a range. |

**Tier metals (the only saturated colour in the entire app):**
bronze `#C8834E` · silver `#C3C7CE` · gold `#E7B23C` · platinum `#E3EAF0` · diamond `#8AE0F2`

**There is deliberately NO error colour for logged food.** Going over your calorie
band is not an error, it's Tuesday. If you find yourself wanting red for "over
budget", that's the rule working.

## Type

SF Pro (`system-ui`). Numbers that update in place use **tabular figures**.

| Style | Size/line | Weight | Use |
|---|---|---|---|
| display | 40/44 | 600 | Onboarding step headings, rank tier name. |
| title1 | 28/34 | 600 |  |
| title2 | 22/28 | 600 |  |
| title3 | 20/25 | 600 |  |
| headline | 17/22 | 600 | Food name in a row, card titles. |
| body | 17/22 | 400 |  |
| callout | 16/21 | 400 |  |
| subhead | 15/20 | 400 | Brand and portion under a food name. |
| footnote | 13/18 | 400 |  |
| caption | 12/16 | 400 |  |
| label | 11/14 | 600 | Section eyebrows, stat card labels. |
| metricXL | 56/58 | 600 | The composite score on the rank screen. One per screen, maximum. |
| metricL | 40/44 | 600 | Calories remaining. |
| metricM | 28/32 | 600 |  |
| metricS | 17/22 | 600 | kcal on a food row. |

## Space, radius, motion

- Spacing: 4pt grid — `4 8 12 16 20 24 32 48 64`. Default gutter and card padding: 16.
- Radius: `8` chips · `12` inputs/rows · `16` cards · `24` sheets · `999` pills. Always
  iOS continuous curve.
- **Elevation differs by scheme:** dark mode uses a surface lightness step + 1px
  hairline and **no shadow** (shadows don't read on near-black). Light mode uses a
  soft shadow.
- Motion: `120ms` press · `200ms` row insert · `300ms` sheet — **300ms is the ceiling
  for everything routine.** One exception: the weekly rank reveal at `900ms`. Respect
  `prefers-reduced-motion`.

## The seven rules

1. **The baseline is always on screen.** No number appears alone. `78.4 kg` is always
   `78.4 kg` + `−1.2 kg vs 4 weeks ago`. Every chart draws the 4-week baseline line.
2. **Quiet by default, loud once a week.** Attention is a budget spent almost entirely
   on the rank reveal. Saturated colour → tier metals only. Motion over 300ms → the
   reveal only. 56pt type → once.
3. **Ranges, not points.** Calorie targets are bands (`1,750–1,950`, never `1,847`).
   Photo estimates are ranges + confidence. Weight is a 7-day average; raw dailies are
   off by default because daily weight is mostly water and glycogen.
4. **Regression is a reset, never a failure.** A missed day is an *empty* notch, never
   crossed out or red. Losing a tier says "Reset to Silver. Gold is four consistent
   days away." No streak-break animation. Ever.
5. **"No data" is a designed state.** iOS won't tell you if HealthKit read access was
   denied — an empty result is identical to "no data". So no-data and
   permission-not-granted are worded **the same way**, and neither reads as broken. No
   warning icons, no "failed to load".
6. **Three tabs: Today · Log · Rank.** Two taps from cold open to a logged meal — tap
   Log, tap a frequent food, which logs immediately at its last portion with an undo
   toast. That's the measurable claim against MyFitnessPal.
7. **The engine is the product.** The rank screen must always answer: what's my tier,
   which component moved it, and what's the cheapest thing that would move it next.

## The tier badge — the one distinctive idea

Tier is encoded as **notch count**, not colour. A shield/chevron with N notches cut
down from its top edge: Bronze 1 → Diamond 5.

Two reasons: silver and platinum are near-identical metals (1.14:1 luminance apart, so
colour alone can't separate them), and ~1 in 12 men have some colour vision deficiency.
Count is colourblind-safe and reads as a silhouette at tab-bar size.

It's also what the app is *named* after — a notch is a tally mark, "one more than
before", which is the thesis in a single image.

SVG (100×120 viewBox), notches fixed 9 wide with 6 gaps, centred, 30 deep:

```html
<svg viewBox="0 0 100 120" width="120">
  <mask id="n3">
    <rect width="100" height="120" fill="#fff"/>
    <rect x="35.5" y="-4" width="9" height="30" rx="3" fill="#000"/>
    <rect x="50.5" y="-4" width="9" height="30" rx="3" fill="#000"/>
    <rect x="65.5" y="-4" width="9" height="30" rx="3" fill="#000"/>
  </mask>
  <path d="M8 4h84a5 5 0 0 1 5 5v60L50 116 3 69V9a5 5 0 0 1 5-5Z"
        fill="#E7B23C" mask="url(#n3)"/>
</svg>
```

For N notches, group width = `N*9 + (N-1)*6`, first x = `(100 - groupWidth)/2`.

The **consistency ring** reuses the same idea: 7 discrete segments, one per day, not a
continuous ring — because consistency *is* whole days, and a continuous ring at 71%
invites "which day was the 0.71?" Filled = positive, empty = stroke. Never red.

## Copy rules

Second person, present tense, plain words. Short sentences. No exclamation marks, no
emoji, **never medical** (no diagnosis, no "you should").

Every string about a shortfall must answer *"what now?"*, not *"what went wrong?"*

| Never | Instead |
|---|---|
| You broke your streak | Welcome back |
| You lost your Gold tier | Reset to Silver. Gold is four consistent days away. |
| You missed 3 days | Logged 4 of 7 days |
| 340 calories over budget | 2,190 — above your band today |
| Your progress has stalled | Weight steady over 4 weeks |
| Bad week | Quieter week than usual |

Also avoid: "cheat meal", "guilt-free", "earn it", "burn off", "budget" for calories
(use *band*), "on track"/"off track" (binary where the truth is a range).

## The six screens

1. **Onboarding · goal & rate** — collects only what the scoring engine needs (DOB,
   height, sex, activity, goal type, rate). Safety gates live here: calorie floor,
   goal weight ≥ BMI 18.5, rate ceiling of min(1 kg, 1% bodyweight)/week. Ends on
   "Your band: 1,750–1,950 kcal — a band, not a number."
2. **Today** — calories remaining vs band · consistency ring 5/7 · weight
   `78.4 kg / −1.2 kg vs 4 wks` · trend sparkline with baseline · tier slot (shows
   "CALIBRATING · 6 days to go" for the first 14 days) · today's logged rows.
3. **Log food** — search field, barcode and camera as peers at the top, then
   FREQUENT (log on tap) and RECENT.
4. **Photo confirm & correct** — mandatory, never silently accept. Honest header:
   "Estimates, not measurements." Per item: name, gram range, kcal range, confidence
   chip. Adjust portion / remove / add missed item. One tap to correct.
5. **Weight & trend** — 7-day average as the headline, dashed 4-week baseline, goal
   band fill, raw dailies behind an off-by-default toggle.
6. **Rank** *(the hero — this is the App Store screenshot)* — eyebrow "WEEK OF 3
   AUGUST" · tier badge at ~110px · "Gold" · "Up from Silver" in positive · composite
   `0.71` in metricXL · then the breakdown with **weights visible**:
   `CONSISTENCY · WEIGHTED 0.50 → 0.86`, `ADHERENCE · 0.25 → 0.71`,
   `PROGRESS · 0.25 → 0.52`, each with a thin progress bar · then a next-step card:
   "**Gold holds at 0.65.** One more logged day next week keeps you there."

   No confetti — it would reward *rate*, which the engine deliberately caps for
   safety. No other user's name or number anywhere. No percentile.

**Constraint that bit me:** all of this has to fit a real 393×852 viewport without
scrolling. My first pass overflowed by 22px and clipped the next-step card. Check it.

═══════════════════════════ PASTE TO HERE ═══════════════════════════

---

## Suggested first prompts

- *"Redesign screen 6 (Rank). Keep every rule, but give it more visual weight — it
  currently reads flat. Show me three directions before you build."*
- *"Design screen 2 (Today) in both light and dark. Verify nothing overflows 393×852."*
- *"The tier badge silhouette — try three alternatives to the shield shape, keeping
  the notch count as the primary signal."*

## When you land something

Bring the hex values or geometry back into `design/tokens/notch.tokens.json`, run
`python3 design/tokens/generate.py`, and the Swift and CSS regenerate. The generator
fails the build if any text/surface pair drops below WCAG AA — so a colour change
that breaks contrast gets caught rather than shipped.
