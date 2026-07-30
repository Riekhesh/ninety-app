# Competitor teardown

§0.4: *"Structured research, not vibes."* Install and genuinely **use** each of these
for one week.

The deliverable is a one-page comparison table plus **ten things you will deliberately
do differently**. §0.4: *"This artifact goes into your final write-up and gives you
concrete, specific answers when an interviewer asks how you approached product
decisions."*

> **You have to do this part.** I can build the instrument; the numbers have to come
> from your thumbs. Budget one week of casual use, then 90 minutes to fill this in.

---

## The apps, and why each one

| App | Why it's on the list |
|---|---|
| **MyFitnessPal** | The incumbent. §0.4: *"notoriously bad"* at time-to-log. Beating it is a measurable claim. |
| **Cal AI** (or similar) | Photo logging — the feature with the most uncertainty in our build |
| **Hevy** | Workout UX, done well. We are *not* building this (ADR 0009) — look at it to confirm that decision, not to get tempted |
| **Strava** | **The problem we are solving.** Post a slow run and watch how it feels. This one is research into the thesis, not the features |
| **Duolingo** | Gamification done properly. Not a fitness app, and §0.4 says *"that's the point"* — the mechanics transfer, the domain doesn't |
| **Yazio** or **Zero** | Onboarding and paywall patterns |

---

## Measurement protocol

**Read this before you measure anything.** Numbers collected under inconsistent rules
are not comparable, and the whole value here is comparability.

### Taps from cold open to a logged meal

§0.4: *"the single most important number in the category."* So define it precisely:

**Cold open** means:
- App fully quit (swipe up from the app switcher), not backgrounded
- Already signed in, onboarding complete
- Phone unlocked, on the home screen
- The app has at least 3 days of prior logging history, so recents and frequents are
  populated the way a real user's would be

**A tap** is one discrete screen touch. Count:
- taps and long-presses (1 each)
- each character of typing (a 6-character search is 6 taps — this is what makes
  search genuinely expensive, and hiding it would flatter search paths)
- scroll gestures (1 per flick)
- system permission dialogs, if they appear in the flow

Do **not** count: Face ID, app launch itself, involuntary interstitials you cannot
avoid (note those separately — they are their own finding).

**Logged** means the food appears in today's total with its energy counted. Not "the
detail screen is open", not "it's in a draft".

**Measure three scenarios separately.** A single number hides the interesting
variation:

| Scenario | What it tests |
|---|---|
| **A · Repeat food** | Something logged before. The common case — most people rotate ~30 foods |
| **B · New food, by search** | Search, pick, set portion, confirm |
| **C · Packaged food, by barcode** | Scan → confirm |

Run each **three times** and record the **median**. First attempts measure your
learning, not the app.

### The other five measures

**Onboarding length** — screens from first launch to being able to log anything.
Count a screen you must dismiss or answer. Note separately: how many screens are
*before* any value is delivered, and whether it is skippable.

**Photo logging** — is a confidence level shown? Is an estimate a range or a single
number? How many taps to correct a wrong item? Can you correct the *portion* separately
from the *identification*? (That last one matters to us — Spike B measures which error
dominates.)

**Streak and gamification** — what is rewarded, what is punished. **Break a streak on
purpose** and screenshot exactly what the app says. That screenshot is the single most
useful artifact in this exercise, because it is the thing §10 tells us not to do, and
having the incumbents' version in front of you makes our copy deck concrete rather
than theoretical.

**Paywall** — where it appears (screen number), what sits behind it, and whether the
free tier is genuinely usable.

**The single most annoying thing** — one sentence, written the same day you notice it.
Do not save this up; irritation fades and you will write something bland a week later.

---

## Results

> `TO BE MEASURED` — fill these in. CI prints outstanding placeholders on every push.

### Taps to log (median of 3)

| App | A · Repeat | B · Search | C · Barcode | Notes |
|---|---:|---:|---:|---|
| MyFitnessPal | `TO BE MEASURED` | | | |
| Cal AI | `TO BE MEASURED` | | | |
| Yazio / Zero | `TO BE MEASURED` | | | |
| Hevy | n/a | n/a | n/a | no food logging |
| **Notch (target)** | **2** | ~8 | ~3 | see below |

**Where Notch's target comes from.** Cold open lands on Today. Tap `Log` (1). Tap a
frequent food (2) — which logs immediately at its last-used portion, with an undo
toast. That is the whole interaction.

The decision that buys it is in `docs/design/02-components.md`: **frequent-food rows
log on tap rather than opening a detail sheet.** It is only safe because of undo, so
undo is part of the component rather than a nice-to-have.

**Verify this on the real app in Phase 1 and put the measured number here.** A target
is not a measurement, and §3.3 instruments time-to-first-log precisely so this claim
can be checked against real users rather than against your own thumbs.

### Everything else

| App | Onboarding screens | Screens before any value | Photo: range shown? | Confidence shown? | Taps to correct | Streak break copy | Paywall at screen | Most annoying thing |
|---|---:|---:|---|---|---:|---|---:|---|
| MyFitnessPal | `TO BE MEASURED` | | | | | | | |
| Cal AI | `TO BE MEASURED` | | | | | | | |
| Hevy | `TO BE MEASURED` | | n/a | n/a | n/a | | | |
| Strava | `TO BE MEASURED` | | n/a | n/a | n/a | | | |
| Duolingo | `TO BE MEASURED` | | n/a | n/a | n/a | | | |
| Yazio / Zero | `TO BE MEASURED` | | | | | | | |

### Strava — the thesis check

This one is different. You are not auditing features, you are checking whether the
premise of the entire project is real.

Post your slowest genuine activity. Then answer honestly:

- Where do you appear on the segment leaderboards? `TO BE MEASURED`
- How does the leaderboard placement make you feel about doing it again?
- Is there **any** metric where a beginner can rank well?
- Does the app acknowledge improvement at all, or only absolute performance?

**If a beginner can already win at something on Strava, the thesis is weaker than it
looks and you should write that down.** §01 claims *"the people with the furthest to
go get the least encouragement, and they quit first."* Check it. A thesis you have
tested is worth more than one you assumed, and finding a hole now is far cheaper than
finding it in Phase 3.

### Duolingo — the mechanics that transfer

Duolingo is on the list because it gamifies well, but the domain difference is
load-bearing: **failing a Spanish lesson is not a health risk, and under-eating is.**
So for each mechanic, decide whether it survives §10:

| Mechanic | Transfers? | Why / why not |
|---|---|---|
| Streaks | `TO BE MEASURED` | |
| Streak freeze / repair | | This one probably does — it's recovery framing, which §09 explicitly wants |
| Leagues (relative, weekly) | | Closest existing thing to our tier ladder — study it |
| Daily reminder push | | Probably **not** — §2.2 wants one notification per week, not twelve |
| XP and levels | | |
| Loss-aversion framing | | Probably **not** — this is the punishment framing §10 bans |

---

## Ten things we will do differently

Each one needs: the observation, our decision, and the section of the brief it traces
to. Vague entries are worthless in a write-up — *"better UX"* is not a claim,
*"2 taps versus their 7"* is.

> Five are pre-filled from decisions already locked in Phase 0. **Fill the remaining
> five from what you actually observe** — those are the valuable ones, because they
> come from evidence rather than from planning.

| # | We observed | So we will | Traces to |
|---|---|---|---|
| 1 | `TO BE MEASURED` taps to log a repeat food in MFP | Log frequent foods on tap, with undo. Target 2 taps. | §0.4, principle 6 |
| 2 | Photo loggers show a single confident kcal number | Always show a **range** plus per-item confidence, and require confirmation | §1.3 |
| 3 | Streak-break copy is punitive | "Welcome back", never "you lost it". 17 phrases banned at lint-error severity | §10, copy deck |
| 4 | Leaderboards rank on absolute performance | Rank only on improvement and consistency against the user's own baseline | §01 — the thesis |
| 5 | Trackers show raw daily weight | 7-day EWMA as the headline; raw dailies off by default | §1.5 |
| 6 | `TO BE MEASURED` | | |
| 7 | `TO BE MEASURED` | | |
| 8 | `TO BE MEASURED` | | |
| 9 | `TO BE MEASURED` | | |
| 10 | `TO BE MEASURED` | | |

**Prompts for the remaining five**, if nothing jumps out — but prefer whatever
actually irritated you, because that is more honest:

- What did the onboarding ask that it did not need? (Ours asks only what the scoring
  engine uses — §1.2)
- Where did an app show false precision it could not support?
- What did the paywall block that made the free tier pointless?
- Where did you have to correct the app twice for the same mistake?
- What did the app do that made you feel judged?
- What was fast in one app that was slow in all the others?

---

## When you're done

- [ ] Six apps used for a week each (they can overlap)
- [ ] Tap counts measured, median of 3, all three scenarios
- [ ] Streak-break screenshots collected
- [ ] Strava thesis check answered honestly, including if it undermines the thesis
- [ ] Ten differences filled in, each traceable to an observation
- [ ] Every `TO BE MEASURED` gone (`grep -rn "TO BE MEASURED" docs/`)

Then this file is a Phase 0 exit criterion met, and a section of the final write-up
already written.
