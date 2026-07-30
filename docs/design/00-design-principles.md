# Design principles

Seven rules. Each one is derived from either the cover thesis or §10, and each one is
falsifiable — you can look at a screen and say whether it holds.

The failure mode §0.5 warns about is "designing forty beautiful screens you never build."
The counter-move is to spend the design effort on **the system and its rules** rather than
on screen count. Rules survive into the code. Screens do not.

---

## 1. The baseline is always on screen

> *"This one compares you to who you were last month."*

If that is the product, then **no number appears alone.** Every metric is shown next to what
it was, and every chart carries a reference line for the user's own four-week baseline.

| Instead of | Show |
|---|---|
| `78.4 kg` | `78.4 kg` · `−1.2 kg vs 4 weeks ago` |
| `1,840 kcal` | `1,840` in a band of `1,750–1,950` |
| `Gold` | `Gold` · `up from Silver` |
| A weight chart | A weight chart **with the baseline line drawn** |

The `chartBaseline` colour token exists for exactly one purpose: drawing "you, four weeks ago."
It is the thesis rendered as a gridline.

**Test:** point at any number in the app. Can you tell whether it is better or worse than the
user's own past, without tapping anything? If not, the screen is wrong.

---

## 2. Quiet by default, loud once a week

The weekly rank-up is the core retention moment (§2.2). It only lands if nothing else is
competing for attention. So attention is a **budget**, and it is spent almost entirely in one
place:

- **Saturated colour** is rationed to the tier metals. Nothing else in the product is
  saturated. Not the accent, not the charts, not the buttons.
- **Motion over 0.3s** is rationed to the rank reveal. Every other transition uses
  `Motion.instant`, `.fast`, or `.base`. The token named `reveal` (0.9s) has exactly one
  legitimate call site.
- **`metricXL` type** (56pt) appears once per screen, maximum, and only on the rank screen.

This is why the direction is "quiet premium" (ADR 0011). A restrained app makes a loud moment
possible. A loud app has nowhere left to go.

**Test:** screenshot the Today dashboard and the rank screen side by side. Is the rank screen
obviously the more important one, without reading a word?

---

## 3. Ranges, not points

§1.2 is explicit: *"Hitting exactly 1,847 kcal is not a real human goal; landing between
1,750 and 1,950 is."*

False precision is a **design bug**, not a formatting preference, and it appears in three
places:

- **Calorie targets** are bands. The band is drawn as a wide soft region, not two tick marks.
- **Photo estimates** are ranges with a confidence level (§1.3). `320–480 kcal`, never
  `400 kcal`.
- **Weight** is a 7-day exponentially weighted moving average. Raw daily weight is available
  behind a toggle, off by default, drawn in `chartRaw` — deliberately faint.

The reason for the weight rule is worth stating plainly because it is easy to get wrong out
of a desire to be "transparent": daily weight is mostly water, glycogen and gut content.
Showing it raw produces a jagged line that makes a genuinely successful week look like
failure. §1.5 names it as one of the main reasons people abandon weight-loss apps in the first
fortnight. **Showing the raw number as the headline is not honesty, it is noise presented as
signal.**

There is no lint rule that can catch all of this, but `no_false_precision_kcal` catches the
most common form.

---

## 4. Regression is a reset, never a failure

§10, verbatim: *"'You broke your streak' becomes 'welcome back.' Losing a tier is framed as a
reset, never as failure. Review every string in the app against this."*

Concretely:

- **There is no error colour for logged intake.** Deliberately absent from the token set. Going
  over your band is not an error — it is Tuesday. The tokens provide `positive` (in band),
  `safety` (a §10 intervention fired), and `critical` (destructive confirmation), and nothing
  in between. A designer reaching for "the red one" for over-budget will not find it.
- **Losing a tier shows the way back**, not the drop: *"Reset to Silver. Gold is four
  consistent days away."*
- **A missed day is drawn as an empty notch**, not a crossed-out one. Absence, not damage.
- **No streak-loss animation.** Ever.

`no_punishment_framing` in `.swiftlint.yml` enforces the string half of this at `error`
severity. The visual half is on review — the PR template asks.

---

## 5. "No data" is a designed state, not an error

§0.7 flags the gotcha: iOS deliberately will not tell you whether the user denied HealthKit
read access. **An empty result is indistinguishable from "this user has no data."**

That has a direct design consequence: every surface that renders health data needs a designed
empty state from the first commit, and it must read as *normal* rather than *broken*. No
warning icons, no red, no "failed to load."

Four states for every data surface, specified in `02-components.md`:

| State | Reads as |
|---|---|
| **Has data** | the data |
| **No data yet** | an invitation ("Log your first meal") |
| **Permission not granted** | an offer, phrased identically to no-data ("Connect Apple Health") |
| **Sync pending** | quietly optimistic — the value is already there, it is just not uploaded |

Note the third and second are worded the same way on purpose. The app cannot distinguish them,
so it must not pretend to.

---

## 6. Three tabs. Two taps to log.

§1.6: *"Three tabs maximum across the whole app."* **Today · Log · Rank.** If a feature needs
a fourth tab, it is out of v1 scope.

The tap count is the design constraint with a number attached, and §0.4 makes it measurable:
*"Taps from cold app open to a logged meal. This is the single most important number in the
category."*

**Target: 2 taps for a repeat food.** Cold open lands on Today → tap `Log` (1) → tap a
frequent food (2), which logs immediately at its last-used portion with an undo toast.

That last part is the design decision that buys the number: **frequent-food rows log on tap
rather than opening a detail sheet.** §1.3's insight is that most people rotate through about
thirty distinct foods, so the common case is re-logging something known. Making the common case
one tap instead of three is a real, measurable product claim against MyFitnessPal — and undo
is what makes it safe.

Record the competitors' numbers in `docs/phase-0/04-competitor-teardown.md` and put ours next
to them.

---

## 7. The engine is the product; the UI is a lens on it

The ranking engine is the differentiator (§2). Everything else "exists to feed it data" — so
the interface's job is to make the engine's reasoning **legible**, not to decorate it.

Practically, the rank screen must always answer three questions without a tap:

1. **What is my tier, and what moved?**
2. **Which of the three components moved it?** — consistency, adherence, progress, shown
   as a breakdown with their weights visible (0.50 / 0.25 / 0.25)
3. **What is the single cheapest thing that would move it next?**

Question 3 is the mitigation §02 asks for. ADR 0008 accepts that consistency-weighted scoring
will feel unresponsive to someone chasing fast results, and specifies *"mitigate through copy,
not by reweighting."* A rank that explains itself is legible rather than arbitrary — and a
legible rank is one the user can act on.

**Test:** show the rank screen to someone who has never seen the app. Can they tell you what
would raise their rank? If not, the engine is invisible and the differentiator is wasted.

---

## Anti-patterns

Specific things not to build, each with the reason:

| Never | Because |
|---|---|
| Red "over budget" state | §10 — punishment framing. There is no error token for intake. |
| Streak-break animation or shaming copy | §10 — "welcome back", not "you lost it" |
| Confetti on weight loss | Rewards rate, which the engine deliberately caps (§10 rate ceiling) |
| Any absolute leaderboard | Inverts the entire thesis |
| Raw daily weight as the headline number | §1.5 — jagged line, first-fortnight churn |
| A single kcal figure from a photo | §1.3 — the model cannot support that precision |
| "You have 340 calories left" as the only frame | Frames food as a budget to spend rather than a band to land in |
| Daily nudge notifications | §2.2 — trains people to disable notifications, losing the channel permanently |
| A fourth tab | §1.6 |
| Hardcoded hex colours | `no_hardcoded_colour` will fail the build |

---

## Voice

Second person, present tense, plain words. Short sentences. No exclamation marks. No emoji in
product copy.

**Never medical.** No diagnosis, no prescription, no "you should." §10 lists App Store
rejection for medical claims as a live risk, and the app genuinely is not qualified to make
them. Notch reports what you logged and how consistent you were. That is all it knows.

Full string-by-string treatment, including the banned-phrase list the linter enforces:
[`04-copy-deck.md`](04-copy-deck.md).
