# Component specs

§0.5 caps the component set: *"Button, text input, food row, stat card, tier badge, chart
container. That's it."* Six, plus one addition — the **notch ring** — justified below.

Every spec lists its states, because **the states are the actual work.** A component with a
happy path and no empty state is a component you will rewrite in Phase 1.

Sizes, colours and radii below are token names, never literals. `no_hardcoded_colour` and
`no_magic_corner_radius` enforce that at `warning` severity.

---

## 1. Button

Three variants. Not four.

| Variant | Fill | Label | Use |
|---|---|---|---|
| **Primary** | `accent` | `textInverse` | The one action that moves the flow forward. **One per screen.** |
| **Secondary** | `surface` + `stroke` hairline | `textPrimary` | Alternatives, "Not now" |
| **Plain** | none | `accent` | Inline, low-stakes, destructive-adjacent |

**Geometry.** Height 50 (44 minimum tap target + breathing room), `Radius.full`, horizontal
padding `Space.xxl`, label `TypeStyle.headline`. Full-width primary on sheets; intrinsic width
elsewhere.

**States.**

| State | Treatment |
|---|---|
| Idle | as above |
| Pressed | `accentPressed`, scale 0.98, `Motion.instant` |
| Disabled | fill at 40% opacity, label `textDisabled`. **Never the only feedback** — pair with text explaining why |
| Loading | label swaps for a spinner, width held. Rare — the UI should not wait on the network (§04) |
| Focused | `Border.focus` ring in `accent`, offset 2. **Never removed.** |

**Destructive** ("Delete account and all data") is a Plain button in `critical`, and it must
require a typed confirmation, not just a tap. This is the one place `critical` is correct.

---

## 2. Text input

**Geometry.** Min height 50, `Radius.md`, `surfaceSunken` fill, `strokeStrong` hairline,
padding `Space.md`. Value `TypeStyle.body`; label `TypeStyle.label` above, not inside — a
placeholder that doubles as the label disappears exactly when it is needed.

**States.**

| State | Treatment |
|---|---|
| Idle | as above |
| Focused | border → `accent` at `Border.focus` |
| Filled | value in `textPrimary` |
| Invalid | border → `safety`, message below in `safety`, `TypeStyle.footnote` |
| Safety-blocked | border → `safety`, message below, **and the primary action stays disabled** |

Note there is no `critical` state on an input. A user typing a goal weight that is too low has
not made an *error* — they have hit a §10 limit, and `safety` is the token that says so. The
distinction is the difference between "you're wrong" and "we won't go there." Copy for all six
interventions: [`04-copy-deck.md`](04-copy-deck.md).

**Numeric inputs** use `TypeStyle.metricS` (tabular figures) and a decimal keypad with an
explicit unit suffix. Never a bare number.

---

## 3. Food row

The most-used component in the app. It appears in search results, recents, frequents, the
day's log, and the photo-correction list, so it has to earn its density.

```
┌──────────────────────────────────────────────────────┐
│  Porridge with milk                          320     │   headline / metricS
│  Tesco · 250 g                               kcal    │   subhead / caption
└──────────────────────────────────────────────────────┘
   ↑ name + brand + portion              ↑ energy, right-aligned tabular
```

**Geometry.** Min height 60, padding `Space.md` × `Space.lg`, `Radius.md` on tap highlight,
`stroke` hairline divider between rows (not around each one).

**Behaviour — this is the load-bearing decision.**

| Context | Tap does |
|---|---|
| **Frequents / Recents** | **Logs immediately** at last-used portion + undo toast |
| Search results | Opens portion sheet (portion is unknown) |
| Today's log | Opens edit sheet — *unless* `locked_at` is set (§2.3, 48h lock), then it is read-only with a "Locked" chip |
| Photo correction | Inline portion stepper, no navigation |

Log-on-tap in Frequents is what makes the 2-tap target (principle 6) achievable. It is only
safe because of undo, so **undo is part of the component, not a nice-to-have.**

**Entry-method chip.** A small `TypeStyle.label` chip shows `SEARCH` / `BARCODE` / `PHOTO` /
`MANUAL` in `textTertiary`. Unglamorous, and it is what makes the Phase 3 "log method split"
metric legible to the user as well as to PostHog.

**States:** idle · pressed (`accentSubtle`) · logged (brief `positive` tick, `Motion.fast`) ·
locked (chip, no affordance) · pending sync (small outbox glyph in `textTertiary` — the value is
already real, it just has not uploaded).

---

## 4. Stat card

The Today dashboard is made of these.

```
┌───────────────────────────┐
│  CALORIES REMAINING       │   label (uppercase, tracked)
│                           │
│  340                      │   metricL, tabular
│  of 1,750–1,950 band      │   footnote — the band, never a point
│                           │
│  ▓▓▓▓▓▓▓▓▓░░░░  in band   │   band indicator + positive
└───────────────────────────┘
```

**Geometry.** `notchCard()` (the generated helper picks hairline-on-dark vs shadow-on-light),
padding `Space.lg`, `Radius.lg`. Grid: two-up for secondary stats, full-width for the primary.

**Required anatomy.** Label · value · **comparison** · optional indicator. The comparison slot
is not optional — principle 1. If a stat has nothing to compare against yet, the slot says so
("no baseline yet — 6 days to go"), which is honest and also explains the calibration window.

**States:** has data · no data yet · permission not granted (worded identically) · calibrating
(within the 14-day window, §2.3) · pending sync.

---

## 5. Tier badge

The differentiator, and the only saturated thing in the app.

**Form.** A shield/chevron with **N notches cut into its leading edge**, where N is the tier's
position 1–5 (ADR 0012). Fill is the tier metal; notches are cut through to the ground behind,
so they read at any size.

```
   Bronze          Silver           Gold          Platinum        Diamond
  ╭──────╮       ╭──────╮        ╭──────╮        ╭──────╮        ╭──────╮
  │▍     │       │▍▍    │        │▍▍▍   │        │▍▍▍▍  │        │▍▍▍▍▍ │
  ╰──╲╱──╯       ╰──╲╱──╯        ╰──╲╱──╯        ╰──╲╱──╯        ╰──╲╱──╯
     1 notch        2               3               4               5
```

**Three sizes.** `sm` 20pt (tab bar, inline in copy) · `md` 44pt (Today dashboard) ·
`hero` 240pt (rank screen only).

**Accessibility.** `Tier.accessibilityLabel` — *"Gold. Tier 3 of 5."* — is generated, so the
count is available to VoiceOver whether or not the badge is seen. The notch count means the
ladder is also legible without colour vision, which colour-only metals are not
(`generate.py` prints which pairs fail: silver/gold at 1.14:1, platinum/diamond at 1.23:1).

**States:** current · previous (40% opacity, used in the reveal transition) · locked/not yet
reached (`stroke` outline only, no fill) · calibrating (outline plus a `TypeStyle.label`
"CALIBRATING" chip — no tier is assigned until the 14-day window closes, §2.3).

**The reveal** is the one place the motion budget opens up: badge scales 0.9 → 1.0 with
`revealSpring` over `Motion.reveal` (0.9s), notches filling in sequence. Gated on Reduce Motion
via `Notch.Motion.animation(_:reduceMotion:)` — with Reduce Motion on, it cross-fades. No
confetti (principle 4 anti-patterns: confetti rewards rate, which the engine caps).

---

## 6. Chart container

Wraps every Swift Chart so axes, baseline and empty states are consistent.

**Anatomy.** Title (`TypeStyle.label`) · range selector (7d / 4w / 3m) · plot ·
**baseline legend**. The legend is mandatory: a reference line nobody can identify is
decoration.

**Rules.**

- `chartLine` for the primary series — the data gets the *primary text* colour, not the accent.
  The accent means "interactive"; a line you cannot tap is not interactive.
- `chartBaseline` dashed line for the four-week baseline, **always drawn.**
- `chartBand` fill for target bands — wide and soft, unmistakably a range (principle 3).
- `chartRaw` dots for raw dailies: off by default, faint when on (§1.5).
- `chartGrid` barely there. Y-axis labelled, X-axis minimal.
- Endpoint emphasised with a filled dot and its value — the current number is what the user
  came for.

**States:** has data · fewer than 7 points ("trend needs a week of data" — the EWMA is not
meaningful yet, and saying so beats drawing a misleading line) · no data · permission not
granted.

---

## 7. Notch ring — *the one addition*

§0.5 lists six components. This is a seventh, and the justification is that §1.6 requires a
"consistency ring" on the Today dashboard, and rendering it as a **continuous** ring would
misrepresent the measurement.

Consistency is `days_logged / 7` with a floor on what counts as logged (§2.2). That is
**seven discrete days**, not a percentage. A continuous ring at 71% invites the question "which
day was the 0.71?" — a seven-segment ring answers it.

```
        ▔▔  ▔▔                 5 of 7 days
      ▕        ▏               ← two empty segments, not "71%"
      ▕        ▏
        ▁▁  ▁▁
```

**Geometry.** Seven segments, 2° gaps, stroke 8 at `md` size. Filled = `positive`,
empty = `stroke`. Centre shows `5/7` in `metricM`.

Missed days are **empty**, never crossed out or `critical` (principle 4). Reusing the notch
metaphor from the tier badge means the design system contains one idea rather than several —
notches are how Notch counts things.

**States:** in progress · complete (all seven filled, brief `positive` pulse at `Motion.fast`)
· week not started · calibrating.

---

## What is deliberately not a component

Because §0.5's "That's it" is the point:

- **Tab bar** — system `TabView`, unstyled. Three tabs.
- **Navigation bar** — system, large titles.
- **Sheets** — system `presentationDetents`. Only `Radius.xl` is ours.
- **Toasts** — one shared implementation for undo. Not a design surface.
- **Confidence pill** on photo estimates — a variant of the entry-method chip, not its own
  component.

If Phase 1 wants an eighth component, it needs a line in this file saying why, in the same shape
as the notch ring above.
