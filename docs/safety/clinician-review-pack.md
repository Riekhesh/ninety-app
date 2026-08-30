# Clinician review pack — Notch safety thresholds

**For the reviewer.** This is a self-contained document. You do not need to see the
app, install anything, or read any other file. **It should take about 30 minutes.**

Everything below is a number I chose from published UK public-health guidance. I am a
computer science student, not a clinician, and the numbers are the part I am least
qualified to set. I am asking you to tell me where they are wrong.

---

## What the app is, in four sentences

Notch is an iOS calorie and weight tracker whose distinguishing feature is that it
**ranks the user on their rate of improvement and their consistency**, rather than on
absolute numbers — the intent being that a beginner can rank well where they cannot on
a conventional leaderboard. It computes a daily calorie target from Mifflin-St Jeor,
tracks weight from the phone's Health app, and lets the user log food by search,
barcode or photo.

It is a student portfolio project. It will go to roughly twenty friends-and-family
testers via TestFlight, and possibly to the public App Store afterwards.

**The risk I am trying to manage** is well documented and I want to be explicit about
it: a gamified calorie tracker with streaks and competitive ranking can reinforce
disordered eating. The app has seven safety requirements built in from the first
version rather than added later. Their *structure* — floors, refusals, ceilings, an
opt-out — I am reasonably confident about. Their *numbers* are what I need checked.

---

## What I am asking for, and what I am not

**I am asking for:** your view on whether these specific numbers are safe and sensible
for an unsupervised consumer app, and — most valuable of all — **anything I have not
thought to include at all.**

**I am not asking you to:** endorse the app, approve it for any purpose, take any
responsibility for it, or be named publicly. I would like to record in the project
that the thresholds were reviewed by someone qualified, and in what role — a first
name and a role ("reviewed by a registered dietitian, September 2026") is enough, and
anonymous is fine too.

**The app makes no medical claims**, carries a "not a medical device, not a substitute
for professional advice" footer throughout, and does not attempt to detect or diagnose
anything.

"This number is fine" is a genuinely useful answer. So is "I don't know, but here is
who would."

---

## 1 · Minimum daily calorie floor

The computed daily target can never go below this, whatever the user asks for. If
Mifflin-St Jeor minus their requested deficit lands lower, the app sets the target at
the floor, says so, and offers a slower rate of loss instead.

| Sex | Floor |
|---|---:|
| Female | **1,200 kcal/day** |
| Male | **1,500 kcal/day** |
| Not specified | **1,500 kcal/day** (the higher of the two, when unsure) |

**Q1.1** Are these the right floors for an app used without supervision?

**Q1.2** *The one I am least comfortable with:* the floor is **flat**. A 1.60 m woman
and a 1.90 m man of the same age are held to the same 1,200/1,500, but the second
person is at a far larger deficit relative to their needs. Should the floor instead be
relative — a percentage of estimated BMR, or never below BMR at all? If so, what
fraction?

**Q1.3** Is defaulting an unspecified sex to the *higher* floor the safe direction, or
does it create its own problem?

---

## 2 · Goal weight validation

The app **refuses** a goal weight whose BMI would be below **18.5** for the user's
height, and tells them the lowest weight it will accept. It does not silently
substitute a different goal. There is deliberately **no upper limit** — someone wanting
to gain to a BMI of 27 is not doing something the app should block.

**Q2.1** Is BMI 18.5 the right refusal line, or should it be higher for this purpose?
A refusal line is not the same thing as a healthy-range boundary, and I may have
conflated them.

**Q2.2** BMI is a poor individual measure — it misreads muscular people, and its
interpretation differs across ethnic groups. Does that argue for a different line, a
different measure, or for keeping BMI precisely because it is conservative here?

**Q2.3** Is having no upper bound right?

---

## 3 · Maximum rate of weight loss

Two things use this number.

**Ceiling:** `min(1.0 kg/week, 1% of current body weight per week)`. So 0.70 kg/week
for a 70 kg user; 1.0 kg/week for a 120 kg user, where the absolute cap binds.

**Selectable rates in setup:** 0.25 / 0.5 / 0.75 kg per week, filtered to those at or
below the user's ceiling. There is no "maximum" option.

**The scoring consequence, which I think is the most important design decision in the
app:** the score **peaks at the user's chosen target rate and falls off above it.**
Losing 1.5 kg in a week scores *lower* than losing 0.5 kg when 0.5 was the target. The
app's headline metric therefore does not reward faster loss at any point.

**Q3.1** Is 1%/week the right relative ceiling? Is the flat 1.0 kg/week cap right at
higher body weights, or unnecessarily restrictive there?

**Q3.2** Is it correct that no user can select 1.0 kg/week even where it is within
their ceiling?

**Q3.3** Does scoring the *appropriate* rate highest rather than the maximum do what I
think it does — or does making the rate a scored target create its own pressure to hit
a number exactly?

---

## 4 · Age gate

Date of birth is collected at setup. **Under 18 is a hard stop with no bypass** — no
"continue anyway", no parental consent route. The rejection screen signposts Beat's
youth helpline rather than leaving the person with nothing.

**Q4.1** Is 18 the right line, or is it over-cautious to the point of pushing under-18s
towards apps with no safety features at all?

---

## 5 · When the app offers support resources

Beat (0808 801 0677) and the National Alliance for Eating Disorders are **always**
available in Settings. The app *additionally* surfaces them — **once, not as a dialogue
box, dismissible, not repeated within 30 days** — when any of these hold:

| # | Pattern | Threshold |
|---|---|---|
| a | Losing faster than their ceiling | for **3 consecutive weeks** |
| b | Eating at the floor | within **5%** of it for **14 consecutive days** |
| c | Trying to set an unhealthy goal weight | **3 or more** rejected attempts |
| d | Eating at the floor while very active | floor-adjacent intake **+** activity in the top decile of their own history |

The copy says only *"if this is feeling difficult, these people help."* No diagnostic
language, no claim to have detected anything.

**These four thresholds are the ones I am least confident about, and I suspect they
are the ones that matter most.**

**Q5.1** Are these too slow? Three weeks and fourteen days both felt long as I wrote
them, but I did not want a nudge on every hard week.

**Q5.2** Which way should I err? A false positive is an unnecessary and possibly
patronising message. A false negative is nothing at all. I have assumed I should err
towards showing it, but I do not know if that is right.

**Q5.3** **Is there a pattern I am not watching for that I should be?** This is the
single most valuable question in this document — I can only look for things I have
thought of.

**Q5.4** Is once-then-quiet-for-30-days right, or should some of these be stickier?

**Q5.5** Is dismissible-and-never-modal right? I reasoned that a message you cannot
dismiss is coercive and gets the app deleted, but I am guessing.

---

## 6 · Two things the app deliberately does not do

**No punishment framing.** No screen tells the user they failed, went over, or broke
anything. A missed day is an *empty* mark, never a crossed-out one. There is no red
"over budget" colour anywhere — it does not exist in the app's colour set, so it cannot
be reached for by accident. Losing rank always states the way back: *"Gold is four
consistent days away."*

**A full opt-out.** One switch turns off every competitive feature — ranks, scores,
streaks, notifications — while food logging, the weight chart and the Health app sync
keep working exactly as before. It is reachable in two taps and is reversible.

**Q6.1** Is there anything here that is well-intentioned but would in practice make
things worse?

**Q6.2** *The question I most want an outside view on.* The app rewards
**consistency** heavily — it is half the score, and in practice that means logging
every day. Is rewarding daily logging itself a risk for someone prone to obsessive
tracking, and does that undercut the whole premise? I do not have a good answer and I
would rather hear it now than after twenty people have used it.

---

## Sign-off

Nothing here is binding on you and none of it will be quoted publicly without asking
first.

| | |
|---|---|
| Reviewed by | |
| Role | |
| Date | |
| Numbers you would change | |
| Anything missing | |
| Happy to be recorded as (name / role only / anonymous) | |

Return it however is easiest — a reply to the email, marked-up text, or five minutes on
a call and I will write it up and send it back to you to check.

---

<sub>Source of these rules: `docs/safety/safety-requirements.md`. Each has a numbered
rule and named automated tests, so a number you change here changes a test there, not
just a paragraph.</sub>
