# Copy deck

§10 requires: *"No punishment framing. 'You broke your streak' becomes 'welcome back.' Losing a
tier is framed as a reset, never as failure. **Review every string in the app against this.**"*

This file is that review, done once, up front, so it does not have to be done in a hurry the
week before TestFlight. The banned-phrase list at the bottom is enforced by SwiftLint
(`no_punishment_framing`, severity `error`), so a regression fails the build rather than
shipping.

**Voice:** second person, present tense, plain words, short sentences. No exclamation marks.
No emoji. **Never medical** — no diagnosis, no prescription, no "you should."

---

## The rewrite rule

Every string that describes a shortfall must answer *"what now?"* rather than *"what went
wrong?"* A string that only names the gap is incomplete.

| ✗ Never | ✓ Instead |
|---|---|
| You broke your streak | Welcome back |
| You lost your Gold tier | Reset to Silver. Gold is four consistent days away. |
| You missed 3 days | Logged 4 of 7 days |
| 340 calories over budget | 2,190 — above your band today |
| Streak lost | Week reset · new week starts Monday |
| You failed to hit your target | Landed above your band on 3 days |
| Try harder tomorrow | Tomorrow is a fresh day |
| Only 2 days logged this week | 2 days logged · 5 to go |
| Your progress has stalled | Weight steady over 4 weeks |
| Bad week | Quieter week than usual |

The pattern: **state the fact neutrally, then give the next action.** "Above your band" is a
fact. "Over budget" is a judgement, and it frames food as money you have spent.

---

## 1. Onboarding

**Sign in**
- Title: `Ninety`
- Sub: `Ranked on how much you improve — not on how you compare to anyone else.`
- Button: `Continue with Apple`
- Footnote: `We ask for your date of birth, height and sex because the scoring engine needs them. Nothing else.`

**About you**
- Title: `A few things the engine needs`
- Fields: `Date of birth` · `Height` · `Sex` · `Activity level`
- Footnote: `Used to work out a realistic starting point for you. Not shared with anyone.`

**Age gate** (under 18 — §10)
- Title: `Ninety is 18+`
- Body: `Ninety isn't built for under-18s yet. Body-image and nutrition content for younger users needs safeguards we haven't built, and we'd rather say so than get it wrong.`
- Body 2: `If you're looking for support with eating or body image, Beat has a youth helpline: beateatingdisorders.org.uk`
- Button: `Close`
- **This is a hard stop with no bypass.** No "continue anyway."

**Goal**
- Title: `What are you aiming for?`
- Options: `Lose weight` · `Maintain` · `Gain weight`
- Rate label: `How fast?`
- Rate options: `Steady · 0.25 kg/week` · `Moderate · 0.5 kg/week` · `Faster · 0.75 kg/week`
- Footnote: `Ninety scores the appropriate rate highest, not the fastest one. Losing weight faster than about 1% of your body weight a week doesn't score better here.`

That footnote is doing real work: it tells the user up front that the rate ceiling exists, so it
does not read as the app being broken when a faster rate does not score higher.

**Your band**
- Title: `Your daily band`
- Value: `1,750–1,950 kcal`
- Body: `A band, not a number. Hitting exactly 1,847 isn't a real goal — landing in this range is.`
- Footnote: `Worked out from your height, weight, age and activity using the Mifflin-St Jeor equation. It's an estimate, and Ninety adjusts as it sees your real data.`

**Calibration explainer**
- Title: `The first two weeks are calibration`
- Body: `Ninety watches your first 14 days to learn your baseline. You won't get a tier until it closes — a rank based on two days of data would be meaningless.`
- Body 2: `Log as normally as you can. An unusually light fortnight makes every week after it look worse by comparison.`
- Button: `Got it`

The second line is the honest version of anti-sandbagging (§2.3): rather than hiding the
defence, tell people the incentive runs the other way.

---

## 2. Safety interventions (§10)

Six requirements, each with its copy. All use the `safety` token, never `critical`. **None of
them blames the user** — they describe a limit the app holds.

> ⚠️ The numeric thresholds below are drawn from widely-used public guidance (NHS, NICE) and
> are recorded in [`docs/safety/safety-requirements.md`](../../docs/safety/safety-requirements.md).
> They are not clinical advice and have not been reviewed by a clinician. **Get them reviewed
> before Phase 3 external testers.**

**Calorie floor** — target would fall below 1,200 kcal (female) / 1,500 kcal (male)
- `Ninety won't set a target below 1,200 kcal a day. Below that it's hard to get enough nutrients, and it usually needs medical supervision.`
- `Your band is set to 1,200–1,400 instead. You can pick a slower rate of loss to widen it.`

**Goal weight below healthy BMI** — target BMI < 18.5
- `That goal weight is below the healthy range for your height (which starts at 58 kg).`
- `Ninety can't set that as a target. You can set 58 kg or above, or switch to maintaining.`

**Rate of loss above ceiling** — > 1% bodyweight/week or > 1.0 kg/week
- `That's faster than about 1% of your body weight a week.`
- `Ninety scores the appropriate rate highest rather than the fastest, so a faster target won't raise your rank — and it's harder to sustain. The fastest option here is 0.75 kg/week.`

**Rapid unexplained loss detected** — sustained rate above ceiling in the data
- `Your weight has been dropping faster than about 1% a week for three weeks.`
- `That's worth mentioning to a GP, especially if it wasn't intentional. Ninety isn't reducing your score for it — it just isn't scoring it higher either.`

**Signposting** — patterns suggest it may help
- `If your relationship with food or your body is feeling difficult, these people help:`
- `Beat — 0808 801 0677 · beateatingdisorders.org.uk`
- `National Alliance for Eating Disorders — eatingdisorderinfo.org`
- `Ninety isn't a substitute for either of them.`

**Competitive opt-out** — must be always available (§10)
- Setting: `Competitive features`
- Body: `Turns off tiers, ranks and scores. Logging, your weight trend and Apple Health sync all keep working exactly as they do now.`
- Confirm: `Turn off competitive features`
- After: `Competitive features are off. You can turn them back on any time — your history is kept.`

The critical property: this switch **must not degrade the app's core usefulness.** It hides the
Rank tab and stops score computation; it does not touch logging or the weight trend.

---

## 3. Today dashboard

- Greeting: `Today` (no name, no time-of-day greeting — it ages badly and adds nothing)
- Calories card label: `CALORIES REMAINING` · value · `of 1,750–1,950 band`
- In band: `In your band` (`positive`)
- Above band: `Above your band` — **not** "over", **not** `critical`
- Below band: `Below your band` + `Eating well under your band slows progress more often than it speeds it up.`
- Consistency ring: `5 of 7 days`
- Weight card: `78.4 kg` · `−1.2 kg vs 4 weeks ago` · `7-day average`
- Tier slot pre-Phase 2: `Ranking arrives in the next update`
- Tier slot during calibration: `CALIBRATING · 6 days to go`

**Empty states** (principle 5 — permission-denied and no-data are worded identically, because
the app genuinely cannot tell them apart):
- Food: `Nothing logged yet today` + `Log a meal`
- Weight: `No weight yet` + `Add today's weight`
- Steps: `No step data` + `Connect Apple Health`
- Steps after connecting, still empty: `No step data` + `Ninety reads steps from Apple Health when they're there.`

---

## 4. Logging

- Search placeholder: `Search foods or scan a barcode`
- Sections: `FREQUENT` · `RECENT` · `RESULTS`
- Log-on-tap toast: `Added · Porridge with milk` + `Undo`
- Empty search: `No match for "quinoa salad"` + `Add it manually` + `Foods come from Open Food Facts and USDA. Anything missing, you can add yourself.`
- Offline: `Saved on your phone. It'll sync when you're back online.` — reassuring, not a warning.
- Locked row: `Locked` + `Logs older than 48 hours can't be edited. It keeps scores honest.`

That last string states the anti-gaming rule plainly instead of leaving a mysterious disabled
control. Users accept a rule they can see the point of.

**Barcode**
- Prompt: `Point at the barcode`
- Not found: `No match for that barcode` + `Search by name instead`

**Photo**
- Prompt: `Photograph your meal`
- Working: `Estimating…`
- Header: `Estimates, not measurements`
- Body: `Ninety is guessing from a photo. It misses cooking oil, hidden sugar and portion size — trained dietitians are 20–30% out and models do worse.`
- Body 2: `That's fine for tracking a trend: a consistent error still shows the direction correctly. Correct anything that looks wrong.`
- Per item: `Porridge with milk` · `200–280 g` · `290–390 kcal` · confidence chip `HIGH` / `MEDIUM` / `LOW`
- Actions: `Adjust portion` · `Remove` · `Add a missed item`
- Confirm: `Log 3 items`
- Low confidence: `Ninety isn't confident about this one — worth a look.`

§1.3 calls owning this limitation loudly "better product design and a far better interview
answer than claiming you solved computer vision." The copy above is that, in the product rather
than in a write-up.

---

## 5. Weight

- Title: `Weight`
- Value: `78.4 kg` · `7-day average`
- Delta: `−1.2 kg vs 4 weeks ago`
- Toggle: `Show daily readings`
- Explainer: `Ninety shows a 7-day average because daily weight is mostly water, glycogen and gut content. The raw line jumps around enough to make a good week look like a bad one.`
- Flat: `Steady over 4 weeks` — flat is a legitimate outcome, not a failure
- Up: `+0.4 kg vs 4 weeks ago` + `Four weeks is a short window. It moves around.`
- Fewer than 7 readings: `Trend needs a week of readings` + `Add today's weight`

---

## 6. Rank

The differentiator. It must answer *what is my tier*, *what moved it*, and *what would move it
next* (principle 7).

**Reveal**
- Eyebrow: `WEEK OF 3 AUGUST`
- Tier: `Gold`
- Sub-line up: `Up from Silver`
- Sub-line same: `Holding Gold`
- Sub-line down: `Reset to Silver` — **never** "dropped", "demoted", "lost"
- Score: `0.71`

**Breakdown**
- `CONSISTENCY · weighted 0.50` — `6 of 7 days` — `0.86`
- `ADHERENCE · weighted 0.25` — `5 of 7 days in band` — `0.71`
- `PROGRESS · weighted 0.25` — `on your expected curve` — `0.52`
- Footnote: `Consistency counts double because showing up predicts results better than any single week does — and it's the part you control.`

**Next step** (always present)
- `Gold holds at 0.65. One more logged day next week keeps you there.`
- After a reset: `Gold is four consistent days away.`
- Best tier: `Diamond is the top tier. Holding it is the whole game now.`

**Progress explainer** — needed because ADR 0008 accepts progress will feel unresponsive
- `Progress is scored against what someone your size would expect to lose, not against a fixed number. Someone at 120 kg loses faster than someone at 70 kg on the same effort — that's physiology, not effort, so Ninety doesn't reward it.`

**Plausibility flag** (§2.3 — flag, don't reject)
- `This week's numbers look unusual, so progress is held at last week's value while Ninety double-checks.`
- `Nothing to do. If it's correct it'll settle on its own.`

Neutral on purpose. §2.3: *"Over-aggressive rejection destroys trust with honest users who
happen to be outliers — and there are always more of those than cheats."* An honest outlier
should not be made to feel accused.

**Calibrating**
- `CALIBRATING · 6 days to go`
- `Ninety is learning your baseline. Your first tier arrives on 17 August.`

---

## 7. Data rights (§10 · UK GDPR Article 9)

- Export title: `Export your data`
- Body: `Everything Ninety holds about you, as JSON: profile, food logs, weights, health samples and weekly scores.`
- Delete title: `Delete your account`
- Body: `Deletes your account and everything in it — logs, weights, photos, scores. Permanently, not hidden. This can't be undone.`
- Confirm: `Type DELETE to confirm`
- Done: `Your account and all its data are deleted.`

"Permanently, not hidden" is deliberate: soft-delete dressed up as delete is the pattern GDPR
exists to prevent, and saying it plainly is a commitment to actually doing it.

---

## Notifications

**One per week** (§2.2). Resist daily nudges — they train people to disable notifications, and
then the channel is gone permanently.

- Rank up: `You're Gold this week. Up from Silver.`
- Held: `You held Gold. Six of seven days logged.`
- Reset: `New week, fresh start. Gold is four consistent days away.`

The reset notification is the one that matters most, and it must not read as bad news. It is a
"come back" message wearing a rank label.

---

## Banned phrases — enforced by SwiftLint

`no_punishment_framing` in `.swiftlint.yml`, severity `error`, matched against string literals:

```
you failed · you lost · lost your streak · streak lost · broke your streak ·
streak broken · you missed · over budget · exceeded your · you blew · ruined ·
demoted · dropped to · too many calories · bad day · be better · no excuses
```

**Also avoid** (not lintable — caught on review, because they need context):

| Phrase | Why |
|---|---|
| "cheat meal" / "guilt-free" / "earn it" | Moralises food |
| "burn off" | Frames eating as a debt |
| "should" | Prescriptive; edges toward medical advice |
| "just" ("just log it") | Minimises the effort the app is asking for |
| "Oops" / "Whoops" | Infantilising |
| "budget" for calories | Money framing — use "band" |
| "on track" / "off track" | Binary where the truth is a range |
| Any medical claim | §10 App Store rejection risk, and untrue |

## Before Phase 3

- [ ] Every string in the app read against the rewrite rule, in one sitting
- [ ] Safety thresholds reviewed by someone clinically qualified
- [ ] Signposting links verified live and UK-appropriate
- [ ] `swiftlint --strict` clean on `no_punishment_framing`
- [ ] Ask three testers to read the reset notification and say how it makes them feel (§3.4)
