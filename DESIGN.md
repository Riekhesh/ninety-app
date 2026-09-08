# Design

<!-- impeccable:design-schema 1 -->

The Matchday world, as it exists in SwiftUI. The world itself was decided on
2026-08-30 and is documented as six artboards in `design/redesign/`; this file
is the build's half — what the artboards mean once they are code, and the rules
that hold when a screen meets a real device instead of a 393×852 frame.

**The artboards are the authority on the world. This file is the authority on
how it is built.** Where they disagree, the deviation is recorded here with its
reason.

---

## Visual world

**MATCHDAY** — a lit football pitch, not a dark app painted green.

| | |
|---|---|
| Ground | Deep warm-shifted pitch green, never neutral black |
| Texture | Mown stripes, vertical, one band per 49pt |
| Light | One floodlight, thrown from the top-left gantry. One source, not an ambient wash |
| Line | Chalk at 2pt. Squared corners, not rounded |
| Colour | One gold, and it belongs to the division |
| Device | Kit stripes — gold, chalk, gold — beside every masthead and nowhere else |

The language runs through the product rather than sitting on it: Matchday, Sub
On, The Table, The Squad, On the Bench, First and Second Half, Form, Divisions.

---

## Mode

**Operate.** Ninety is a tool someone opens for fifteen seconds, several times a
day, usually one-handed and often in a queue. Scanability and native
expectations outrank expression on every screen except one.

**The Table is the exception.** It is the weekly payoff, the App Store hero, and
the only place the app is allowed to be theatrical — `Motion.reveal` at 0.9s has
exactly one legitimate call site and it is there. That contrast only exists
because everything else is quiet: a loud app has nowhere left to go.

---

## Type

Two bundled faces, SIL OFL 1.1, in `Ninety/Resources/Fonts` (ADR 0015).

| Role | Face | Carries |
|---|---|---|
| `ui` | **Saira** | Data, body, controls, every metric |
| `broadcast` | **Saira Condensed** | Mastheads, eyebrows, tab labels |

**Everything scales.** Every style is `Font.custom(_:size:relativeTo:)`, bound to
an iOS text style. The sizes in the tokens are the Large baseline, not a fixed
scale — a layout that only works at one reading size is not finished.

**Never** apply `.weight()` over a style. The weight is in the file; a modifier
on top makes iOS synthesise a bolder outline over a properly drawn one.

**Metric styles are Saira only.** Saira Condensed has no `tnum` table, so
tabular figures silently do nothing on it and digits jitter as a value updates.
`generate.py` fails the build rather than let this happen.

---

## Colour

`design/tokens/ninety.tokens.json` is the only place a colour is decided. Swift,
CSS, and the two asset-catalogue colorsets the app needs before any Swift runs
(the global tint and the launch ground) are all generated from it, and CI fails
on drift.

Three rules that are safety requirements rather than taste:

- **There is no error colour for logged intake.** Going over your band is not an
  error, and the token set deliberately has no red for it. `critical` is
  destructive-confirm only; `safety` is §10 interventions only.
- **Gold is the division's.** It is the only saturated colour in the product and
  the only filled control. Spending it on decoration costs the rank reveal its
  meaning.
- **Tier is never carried by colour alone** (ADR 0012). Chevron count is the
  primary signal — silver and gold differ by 1.09:1.

---

## Structure

**Three tabs, and that is the whole app** (§1.6): Matchday · The Run · The Table.

**Sub On is a sheet, not a tab.** Logging is an action — it has a beginning and
an end and returns you where you started. Apple's rule is that tabs are
sections, and a centre "+" tab is the most common way an iOS app announces it
was designed as a website.

> **Deviation from the artboards.** `Main.dc.html` draws the tab bar as
> MATCHDAY / SUB ON / TABLE. The build uses Matchday / The Run / The Table with
> Sub On presented as a sheet. The artboard's version spends one of three tabs
> on a control and leaves weight with no home; this keeps the same three-tab cap
> and gives every tab a destination.

> **Deviation from the world.** The sign-in screen's only control is
> `SignInWithAppleButton`, drawn in Apple's own style rather than the gold
> primary. Its appearance is fixed by the Human Interface Guidelines, and an app
> that draws its own "Continue with Apple" is a rejection waiting to happen.
> Everything around it — masthead, kit stripes, pitch — is the world; the button
> is Apple's. It is also the one screen with no gold-filled control on it, which
> costs nothing: the division has not been earned yet.

**The system tab bar stays the system tab bar.** It is themed through the layer
UIKit leaves open — sunken ground, gold selection, the broadcast face on the
labels — and keeps scroll-to-top, the sidebar adaptation, VoiceOver's tab
semantics, and every presentation Apple adds later. SF Symbols carry the bar; the
authored chalk glyphs belong in the content, where a 2pt line has room to be one.

Every screen is built in `Screen`, which owns the gutter, the pitch and the
masthead so the spine lands in the same place on all three tabs.

**Settings is a sheet from Matchday's masthead, and the masthead holds exactly
one control.** §10 S6 requires the competitive opt-out within two taps of the
Today screen, and the three-tab cap means Settings can be neither a fourth tab
nor three taps deep. The masthead grew an `accessory` slot for it — one glyph at
the trailing edge, `EmptyView` on every other screen — and nothing else is going
in there. Anything that wants to live at the top of a screen belongs in its
content.

> **Deviation from the artboards.** None of the six screens has a settings
> control, because none of them was drawn after the §10 gates were written. The
> alternative to adding one was burying an eating-disorder helpline and a consent
> withdrawal somewhere they could not be found, which is not a design decision
> the artboards were making.

**Pre-Season is four screens, and the last one carries two things.** About you ·
starting weight · goal · your band. The band screen also holds the calibration
explainer, because finishing the flow is what writes the goal — putting the write
a screen earlier would let a user who quit on the last screen into the app
without ever reading why there is no division yet.

---

## Motion

**Nothing except the weekly rank reveal may exceed 0.3s.** `instant` (0.12s) for
press feedback, `fast` (0.2s) for a row arriving, `base` (0.3s) as the ceiling
for everything routine, `reveal` (0.9s) once a week.

Reduce Motion is honoured through `Ninety.Motion.animation(_:reduceMotion:)`,
which returns `nil` so the change lands instantly rather than in a shorter
animation.

**Banned outright, and not for taste:** no confetti or celebration of speed (the
engine caps rate of loss for safety; celebrating speed would fight it), and no
streak-loss animation of any kind.

---

## Copy

`design/spec/04-copy-deck.md` is the source. Two rules bind every string:

**State the fact, then give the next action.** "Above your band" is a fact;
"over budget" is a judgement that frames food as money spent. A string that only
names the gap is incomplete.

**A missed day renders empty, never crossed out.** Regression is a reset. Losing
a division always names the way back.

**A failure the user chose is not a failure.** Dismissing Sign in with Apple's
sheet shows nothing at all — no banner, no retry prompt. What *is* shown uses
`safety`, never `critical`: the token set has no error colour for a state the
user did not cause, and a red banner over a network blip trains people to ignore
the one that matters.

Seventeen phrases fail the build at error severity (S5), and
`SafetyCopyTests` checks the strings the app actually renders — not only the
literals in source — so the guarantee survives copy moving into a strings file.

---

## Empty states

**There is no permission-denied branch to write.** A denied HealthKit read
returns a result identical to "no data" and iOS will never distinguish them
(Phase 0, measured). Every data surface needs one empty state whose wording
covers both without claiming either.

Never a spinner or a skeleton where the answer is "there is nothing yet" — those
promise content is a moment away. `HoldingNote` states what the surface will
hold and what has to land first. **Never lorem, never an invented number.**

**Launch is the one genuine wait**, and it still gets no spinner. `LaunchHold`
draws the masthead and the pitch and nothing else while the session is read back
from the Keychain, so it reads as the launch screen continuing rather than as a
new screen arriving. In the common case — nobody signed in — it is gone before
it draws.

---

## Accessibility

- WCAG AA, enforced mechanically: `generate.py` refuses a failing pair.
- Dynamic Type at every style, with reflow at accessibility sizes. Every view
  ships an `.accessibility5` preview.
- 44×44pt minimum on every tappable control.
- Tier legible without colour (ADR 0012).
- Text set in caps via `.textCase`, never in the string — VoiceOver spells an
  all-caps literal out letter by letter.
- Both appearances are real. Dark is the default (ADR 0011); light is full
  parity and is previewed alongside it.

---

## Still to come

From `design/redesign/README.md`, unchanged and still outstanding: a real crest
(the app icon is the kit device standing in for one), motion — a score flapping
over, the ball settling — texture on the pitch, the promotion moment as an event
rather than a line, and an App Store hero.
