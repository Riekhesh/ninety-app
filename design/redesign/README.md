# The redesign — Matchday

The visual world the app is built in, as six screens. Decided 2026-08-30 after three
directions were built at full fidelity and two were cut.

**The palette is not here.** It lives in `design/tokens/notch.tokens.json` and reaches
SwiftUI through `generate.py`. Change a colour there, never in these files.

---

## The six screens

| | Screen | What it is |
|---|---|---|
| 1 | [Pre-Season](screens/1-pre-season.png) · `Signing.dc.html` | Onboarding. Every §10 safety gate, stated rather than hidden |
| 2 | [Matchday](screens/2-matchday.png) · `Main.dc.html` | The daily driver: band, pitch, team sheet |
| 3 | [Sub On](screens/3-sub-on.png) · `SubOn.dc.html` | Food logging — four routes, the squad, the bench |
| 4 | [Under Review](screens/4-under-review.png) · `Var.dc.html` | The photo check. Nothing logs until you give the decision |
| 5 | [The Run](screens/5-the-run.png) · `Season.dc.html` | Weight and trend against the pace you chose |
| 6 | [The Table](screens/6-the-table.png) · `Table.dc.html` | The hero. Rank as a league table |

`screens/` is rendered from the artboards at 2× — regenerate rather than edit.

---

## The world

A **lit pitch**, not a dark app painted green: mown stripes, a floodlight thrown from
the top-left gantry, chalk at 2px, one gold that belongs to the division and nothing
else. Kit stripes are the club device in every masthead.

The language runs through the product rather than sitting on it — Matchday, Sub On,
The Table, The Squad, On the Bench, First and Second Half, Form, Divisions.

Two rules this pass established, both recorded in `PRODUCT.md`:

- **Tier is a division**, carried by chevron count and the word. Never colour alone
  (ADR 0012 — silver and gold differ by 1.09:1).
- **A range renders as one figure plus a tolerance** (`612 ±100`), never two numbers
  joined by a dash.

## What holds in every screen, and is not taste

Enforced by lint and tests, not preference — see `docs/safety/safety-requirements.md`:

- No punishment framing. Losing a division always names the way back.
- A missed day renders **empty**, never crossed out.
- **No error colour for logged intake.** Going over the band is not an error.
- Weights are visible on the rank breakdown (0.50 / 0.25 / 0.25).
- The target is a **band**, never a single number.
- No other user's name, number or percentile anywhere in v1.

---

## Working on it

The artboards are Design Component HTML — plain markup with inline styles, no build
step. Open one in a browser to see it, or edit and re-seed the canvas:

```bash
node "<design-skill>/seed-canvas.mjs" --template "<design-skill>/payload.template.html" \
  --out notch-redesign.html --title "Notch Redesign" \
  --artboard Main.dc.html --artboard SubOn.dc.html --artboard Table.dc.html \
  --artboard Signing.dc.html --artboard Var.dc.html --artboard Season.dc.html \
  --canvas canvas.json
```

`notch-redesign.html` is the seeded canvas — **gitignored**, because it is 2.5 MB of
generated editor payload rebuilt from these files on demand.

---

## What this is not

**A base, not a finish.** Structure, language and the safety grammar are settled. Still
to come, on top: a real crest, motion (a score flapping over, the ball settling),
texture on the pitch, the promotion moment as an event rather than a line, and an App
Store hero.

**One thing a 393×852 artboard could not settle:** fixed type scale vs **Dynamic Type**.
iOS wants system text styles and no hard-coded point sizes; these mockups use the fixed
scale because a static frame cannot express the alternative. It is Phase 1's first
design task and it changes how the type tokens are structured.
