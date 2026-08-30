# Competitor teardown

§0.4: *"Structured research, not vibes."* Install and genuinely **use** each of these
for one week.

The deliverable is a one-page comparison table plus **ten things you will deliberately
do differently**. §0.4: *"This artifact goes into your final write-up and gives you
concrete, specific answers when an interviewer asks how you approached product
decisions."*

> **Split of work.** The *measured* numbers have to come from your thumbs — tap counts,
> onboarding screens, streak-break screenshots. Those are below and still open.
> The *structural* facts about these apps are publicly documented, so the
> [desk research](#desk-research--done-from-public-sources) section is filled in
> already, with sources. It answers four of the remaining five differences on its own.
>
> What's left for you: a week of casual use, then ~60 minutes of counting.

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

## Desk research — done from public sources

Everything here is publicly documented and cited. It is **not** a substitute for using
the apps: none of it is a tap count, and product behaviour changes without notice.
Treat it as the *structural* half of the teardown, and confirm anything load-bearing
when you install them.

### The headline facts, per app

| App | The big thing | Why it matters to us |
|---|---|---|
| **MyFitnessPal** | **Barcode scanning is behind the $19.99/mo Premium paywall** for new users. Users had spent years populating that barcode database themselves, and the change was widely read as a betrayal. | §1.3 calls barcode *"the fastest logging path that exists for packaged food and close to free to implement."* The incumbent charges $19.99/mo for it. Ours is free, and that is a concrete, checkable claim rather than a vague UX boast. |
| **Cal AI** | Photo estimates are presented as a **single confident number**, mixed dishes get misidentified, and reviewers report **no way to correct a wrong estimate**. One review had it return "tikka masala" for a photo of an apple. | This is the exact failure §1.3 bans. Our confirm-and-correct screen is mandatory, and correction is one tap. |
| **Hevy** | Deep set/rep/weight logging — a whole application's worth of UI. | Confirms [ADR 0009](../decisions/0009-no-workout-logging-in-v1.md). Look at the size of it and feel relieved you are reading workouts passively from HealthKit instead. |
| **Strava** | Segment leaderboards are hyper-local, and **Local Legend ranks by how *often* you run a segment over 90 days, regardless of pace.** | **This is the closest prior art to our thesis, and it partly pre-empts it.** See the thesis check below — it is the most important thing in this document. |
| **Duolingo** | Streaks built explicitly on **loss aversion**, softened by **streak freeze** and paid **streak repair**. Widely praised as effective and widely criticised as a guilt engine. | The freeze/repair recovery mechanic transfers cleanly (§09 wants recovery framing). The loss-aversion framing does not survive §10. |
| **Yazio / Zero** | Onboarding front-loads questions, then paywalls before first real value. | §1.2 restricts onboarding to *only* what the scoring engine needs. Measure their screen count against ours. |

### The strongest external evidence we have

An **NIH-affiliated study presented at NUTRITION 2026** tested four photo-based calorie
apps — MyFitnessPal, Lose It!, Cal AI and Appediet — and found they **underestimated
meals by 250–345 kcal on average, and fat by roughly 30 g**, about a third of actual
content. High-fat dishes had the largest errors, because cooking oil, butter, dressing
and the fat in a cut of meat are **invisible to a camera**.

Three consequences for us, all concrete:

1. **It independently confirms §1.3's blind-spot claim** — the brief says vision models
   miss cooking oil and hidden fats; a controlled study now says so with numbers.
2. **It sets the bar our benchmark is measured against.** If Spike B's 20 weighed meals
   land near or better than a third-off, that is a *published* comparison point rather
   than a number in a vacuum. §0.7 says most student projects cannot answer "how
   accurate is it really?" — this makes our answer comparative.
3. **It makes rule 3 of the collection protocol non-negotiable.** The protocol says weigh
   and log cooking oil separately. This study is why: omit it and you reproduce exactly
   the error the incumbents make, and hide the failure you are trying to measure.

*Caveat, and it matters for the write-up:* this was a **conference abstract, not a
peer-reviewed paper.** Cite it as such.

**Sources:** [XDA — MFP barcode paywall](https://www.xda-developers.com/myfitnesspals-barcode-scanner-behind-a-paywall/) ·
[NIH study, ScienceDaily](https://www.sciencedaily.com/releases/2026/07/260726015237.htm) ·
[NIH study, Medical Xpress](https://medicalxpress.com/news/2026-07-photo-based-calorie-tracking-apps.html) ·
[Drugs.com — four apps tested](https://www.drugs.com/news/accurate-photo-based-calorie-apps-4-put-test-130774.html) ·
[Cal AI review](https://www.eesel.ai/blog/cal-ai) ·
[Strava Local Legends](https://support.strava.com/en-us/articles/15401751-local-legends) ·
[Strava leaderboard design analysis](https://trophy.so/blog/how-strava-uses-segmented-leaderboards-to-drive-engagement)

---

## Results

> **Deliberately not measured. This criterion is closed on desk research plus prior
> hands-on use of these apps** — see [Scope decision](#scope-decision--closed-without-tap-counts).
> The measurement protocol above is kept because §3.3 instruments time-to-first-log in
> Phase 3, and the definitions there are what make our own number comparable.

### Taps to log

| App | A · Repeat | B · Search | C · Barcode | Notes |
|---|---:|---:|---:|---|
| MyFitnessPal | not measured | | | Barcode requires Premium — see desk research |
| Cal AI | not measured | | | |
| Yazio / Zero | not measured | | | |
| Hevy | n/a | n/a | n/a | no food logging |
| **Notch (target)** | **2** | ~8 | ~3 | see below |

**Where Notch's target comes from.** Cold open lands on Today. Tap `Log` (1). Tap a
frequent food (2) — which logs immediately at its last-used portion, with an undo
toast. That is the whole interaction.

The decision that buys it is in `design/spec/02-components.md`: **frequent-food rows
log on tap rather than opening a detail sheet.** It is only safe because of undo, so
undo is part of the component rather than a nice-to-have.

**This target is unverified against a competitor baseline.** It stays a *design target*
until Phase 1 builds it and §3.3 measures time-to-first-log on real users. Do not put
"2 taps versus their 7" in the write-up — the 7 was never counted. **"2 taps, measured
in-app"** is a claim we will actually have.

### Everything else

Not tabulated. What the apps do structurally is in
[desk research](#desk-research--done-from-public-sources) with sources; the per-app
screen counts were judged not worth the week.

### Strava — the thesis check

This one is different. You are not auditing features, you are checking whether the
premise of the entire project is real.

The questions worth answering:

- Where do you appear on the segment leaderboards? *(not measured)*
- How does the leaderboard placement make you feel about doing it again? *(not measured
  — and this is the half that matters for retention, so it stays an open question rather
  than a settled one)*
- Is there **any** metric where a beginner can rank well? → **Yes.** Answered below.
- Does the app acknowledge improvement at all, or only absolute performance? → Frequency,
  yes; improvement relative to a baseline, no. Answered below.

**If a beginner can already win at something on Strava, the thesis is weaker than it
looks and you should write that down.** §01 claims *"the people with the furthest to
go get the least encouragement, and they quit first."* Check it. A thesis you have
tested is worth more than one you assumed, and finding a hole now is far cheaper than
finding it in Phase 3.

#### Partial answer from desk research — and it is not the comfortable one

**A beginner can already win at something on Strava.** [Local
Legend](https://support.strava.com/en-us/articles/15401751-local-legends) awards a crown
to whoever completes a segment **most often over a rolling 90 days, regardless of
pace.** That is a consistency ranking a slow beginner can genuinely top. Strava also
scopes segment leaderboards hyper-locally rather than globally, which is the same
"make the reference group winnable" instinct behind our tier ladder.

So the strong form of §01 — *"every fitness app compares you to other people"* and
beginners can never win — **is too strong as written, and we should stop saying it that
way.** An interviewer who knows Strava will catch it, and getting caught overclaiming is
far worse than having narrowed the claim ourselves.

**What survives, and it is still the whole project:**

| | Strava Local Legend | Notch |
|---|---|---|
| Rewards | raw **frequency** on one segment | **improvement rate + consistency** |
| Normalised for starting point? | **No** | **Yes** — the DOTS/Wilks-style coefficient in §2.2 |
| Anti-gaming | none needed; nothing to fake | calibration window, edit lock, delta cap, z-score flags (§2.3) |
| Scope | one segment you chose | your whole logged behaviour |
| Still the headline? | no — the fastest time is | **yes** — it *is* the rank |

Local Legend is a **side achievement next to a leaderboard still headlined by absolute
speed.** Nobody has made normalised improvement *the ranking itself*, and normalising
across starting points is the part §01 correctly identifies as the hard engineering
problem. Frequency counting is not that.

**Rewrite the pitch accordingly.** Not *"nobody rewards consistency"* — Strava does, and
the correct move is to cite it as prior art the way §01 already cites Wilks and DOTS.
The claim is *"consistency is a side badge everywhere it exists; here it is the rank,
and it is normalised so a 120 kg beginner and a 70 kg regular can be compared fairly."*
That is narrower, true, and much harder to knock down.

**The half still unanswered:** how a bad placement actually *feels*. Desk research cannot
get this, and it is the half that drives retention. Left open deliberately — Phase 3's
real testers answer it better than one person's Strava post would have.

> **Acted on 2026-08-30.** The narrowed wording is now the wording, everywhere the claim
> is stated — README, the design system page, and the paste-into-Claude design brief. The
> decision and the exact replacement sentence are in
> [ADR 0013](../decisions/0013-narrowed-thesis-claim.md). This section is the evidence;
> the ADR is the call.

### Duolingo — the mechanics that transfer

Duolingo is on the list because it gamifies well, but the domain difference is
load-bearing: **failing a Spanish lesson is not a health risk, and under-eating is.**
So for each mechanic, decide whether it survives §10:

| Mechanic | Transfers? | Why / why not |
|---|---|---|
| Streaks | **Partly** | The count itself is fine. What does not transfer is making the *number* the reward — ours is an input to consistency scoring (§2.2), not a trophy. Note the streak is already load-bearing for us: consistency is weighted 0.50. |
| Streak freeze / repair | **Yes** | Recovery framing, which §09 explicitly wants and §10 requires. Adopt it, but **free** — Duolingo sells repair, and monetising recovery is precisely the punishment-with-a-price-tag §10 bans. |
| Leagues (relative, weekly) | **Yes — this is the closest prior art to the tier ladder** | Weekly, relative to a small cohort, promotion and relegation. Our tiers are fixed-threshold in v1 ([ADR 0007](../decisions/0007-fixed-tier-thresholds.md)) because we have no population yet — but leagues are what this becomes at Phase 4 scale. Study the *relegation* copy hardest; that is our "losing a tier" moment. |
| Daily reminder push | **No** | §2.2 wants one meaningful notification a week, not twelve. Duolingo's escalating reminders are the most-criticised part of the product and train people to disable notifications permanently. |
| XP and levels | **No** | A second currency competing with the tier for attention. §07 says the engine is the product; two scores means neither is the score. |
| Loss-aversion framing | **No** | Duolingo's streak works by making loss hurt roughly twice as much as the equivalent gain. That is the documented mechanism, it is effective, and it is exactly what §10 bans — because in a calorie app the behaviour it drives is not "do one more lesson", it is "do not eat". This is the single clearest place where a proven retention mechanic must be left on the table. |

**The one-line version for the write-up:** Duolingo's mechanics divide cleanly into the
ones that reward showing up (adopt) and the ones that punish stopping (reject). The
domain difference is load-bearing — failing a Spanish lesson is not a health risk.

---

## Ten things we will do differently

Each one needs: the observation, our decision, and the section of the brief it traces
to. Vague entries are worthless in a write-up — *"better UX"* is not a claim,
*"2 taps versus their 7"* is.

> Five were pre-filled from decisions locked in Phase 0. **Four more are now filled from
> desk research** (marked 📚) and are cited above. **One is left deliberately blank** —
> number 10 must come from something that actually irritated you, because a list of ten
> researched differences with nothing personal in it is a worse artifact than nine plus
> one real grievance.

| # | We observed | So we will | Traces to |
|---|---|---|---|
| 1 | Logging a repeat food in MFP takes several screens — §0.4 calls it *"notoriously bad"* at this | Log frequent foods on tap, with undo. Target 2 taps, verified in-app in Phase 3 | §0.4, principle 6 |
| 2 | Photo loggers show a single confident kcal number | Always show a **range** plus per-item confidence, and require confirmation | §1.3 |
| 3 | Streak-break copy is punitive | "Welcome back", never "you lost it". 17 phrases banned at lint-error severity | §10, copy deck |
| 4 | Leaderboards rank on absolute performance | Rank only on improvement and consistency against the user's own baseline | §01 — the thesis |
| 5 | Trackers show raw daily weight | 7-day EWMA as the headline; raw dailies off by default | §1.5 |
| 6 📚 | MFP puts **barcode scanning behind $19.99/mo Premium** — the fastest logging path in the category, paywalled | Barcode free, forever, and **prioritised** as the primary packaged-food path | §1.3, §03 (no paywall in v1) |
| 7 📚 | Cal AI reviewers report **no way to correct a wrong estimate** | Correction is a **first-class interaction**, not a recovery path: portion correctable separately from identification, one tap | §1.3, Spike B |
| 8 📚 | A controlled study found photo apps miss **250–345 kcal/meal**, mostly **invisible fat** | **Prompt explicitly for cooking oil, butter and dressing**, and surface a "hidden fats?" nudge on fried and composite dishes rather than staying silent | §1.3, NUTRITION 2026 |
| 9 📚 | Duolingo **sells streak repair** — monetising recovery from a broken habit | Recovery mechanics are **free and unlimited**. A user rebuilding a habit is the last person to charge | §10, §09 |
| 10 📚 | Yazio/Zero front-load onboarding questions and paywall before delivering any value | Onboarding collects **only what the scoring engine consumes** — DOB, height, sex, activity, goal type, target rate — and the Today screen is usable immediately. No paywall in v1 at all | §1.2, §03 |

**If something does irritate you later**, replace one of the researched entries with it.
A difference that came from your own annoyance is worth more in a write-up than one that
came from a search result, and swapping is free:

- What did the onboarding ask that it did not need? (Ours asks only what the scoring
  engine uses — §1.2)
- Where did an app show false precision it could not support?
- What did the paywall block that made the free tier pointless?
- Where did you have to correct the app twice for the same mistake?
- What did the app do that made you feel judged?
- What was fast in one app that was slow in all the others?

---

## When you're done

- [x] Desk research: headline facts per app, with sources
- [x] Duolingo mechanics assessed one by one against §10
- [x] Strava thesis check — and it narrowed the claim
- [x] Comparison table plus ten deliberate differences
- [x] No `TO BE MEASURED` placeholders left in this file

**Criterion closed.**

---

## Scope decision — closed without tap counts

**Decided 2026-07-30.** §0.4 asks for a week of hands-on use per app and a measured
tap count. That was **deliberately not done.** Recording it here because §00 rule 2 is
that phases end on a testable condition, and a criterion closed on different evidence
than originally written should say so rather than quietly appear ticked.

**What it rests on instead:** prior personal use of these apps, plus the sourced desk
research above.

**What we gave up, honestly:**

1. **The headline number of the category.** §0.4 calls taps-to-log *"the single most
   important number"* and MFP *"notoriously bad"* at it. We cannot now say "2 taps
   versus their 7" — only "2 taps, measured in our own app". Weaker, but still a real
   claim, and §3.3 measures ours on real users in Phase 3.
2. **The streak-break screenshots.** These were meant to make the copy deck concrete
   rather than theoretical. The copy deck already bans 17 phrases at lint-error
   severity, so the rule is enforced either way — it just is not illustrated.
3. **The felt experience of a bad Strava placement**, which is the emotional half of
   §01 and the half that predicts churn.

**Why it is an acceptable trade:** the differences that actually shape the build —
barcode paywalling, absent correction paths, invisible-fat error, monetised recovery,
front-loaded onboarding — are structural, documented, and now cited. Counting taps
would have confirmed a ranking already known from using them. The week is better spent
on Swift, which is genuinely on the critical path.

**What would reopen this:** if a Phase 3 tester says logging feels slow, the competitor
baseline suddenly matters, and it is an evening's work to collect then — against a real
complaint rather than in the abstract.

Then this file is a Phase 0 exit criterion met, and a section of the final write-up
already written.
