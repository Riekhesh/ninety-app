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

**Sign in — when it doesn't work**

Failure states use these, never a raw error string. `cancelled` deliberately has no copy:
dismissing Apple's sheet is a decision, and answering a decision with a banner is arguing
with the user about something they did on purpose.

| State | Line | Second line |
|---|---|---|
| Cancelled at Apple's sheet | *nothing shown* | — |
| Apple returned no token | `Apple didn't hand back a sign-in token. Worth another go.` | — |
| No network | `Can't reach Ninety right now. Check your connection and try again.` | `Anything already on this phone stays where it is.` |
| Server declined | `Ninety couldn't finish signing you in. Try again in a moment.` | — |
| Build has no project (developer only) | `This build isn't connected to a Ninety project yet.` | `Config/Local.xcconfig needs SUPABASE_HOST and SUPABASE_ANON_KEY. See docs/security/secrets.md.` |
| Sign-out not confirmed | `Signed out on this phone. The server hasn't confirmed it yet.` | — |

Only a real network error gets the offline wording. Mapping every failure to "check your
connection" states a cause the app does not know, which is the same class of mistake as
inventing a number.

**Consent** (Article 9 — ADR 0017)

Two decisions on one screen, each with its own switch, each recorded separately. The screen
is a gate on the app starting, so it has to offer the honest alternative rather than a dead
end.

- Masthead: `Pre-Season` · meta `Consent`
- Title: `Before Ninety holds anything`
- Terms heading: `Terms of use`
- Terms body: `What Ninety does, what it doesn't promise, and that it isn't a medical device and makes no medical claims.`
- Terms switch: `I accept the terms`
- Health heading: `Health data`
- Health body: `What you log — food, weight, and what Ninety reads from Apple Health — is special category data under UK GDPR. Processing it needs your explicit consent, given separately from the terms above.`
- Health detail: `It stays on your phone and in Ninety's database. It isn't sold, and it isn't shared with anyone. Withdrawing consent stops Ninety processing anything new; it doesn't delete what's already logged, which is a separate request. Both switches are in Settings whenever you want them.`
- Health switch: `I consent to Ninety processing my health data`
- Footnote: `Ninety needs both to start. Health data is what the app is made of.`
- Button: `Kick off` — disabled until both switches are on
- Way out: `Sign out instead`
- Write failed: `That didn't save. Try the switch again.`

Three things the wording is doing deliberately. It **names** health data, the law and the
word "explicit", because a consent screen that never says what is being consented to is not
explicit consent whatever the timestamps say. It says *"given separately from the terms
above"* in the copy as well as in the schema, so the separation is visible to the user and
not only to the database. And it describes what withdrawal **does** as well as where to find
it.

> **Changed in P1-D.** The last sentence used to be missing. The copy deliberately said what
> withdrawal *does* and not where to find it, because until P1-D there was no Settings screen
> and copy pointing at one would have been the same failure as an invented number. There is
> now — the same two switches, in `Settings → Your consent` — so the sentence is true and the
> screen says it. Consent that cannot be withdrawn as easily as it was given was not freely
> given.

**About you**
- Title: `A few things the engine needs`
- Fields: `Date of birth` · `Height` · `Sex` · `Activity level`
- Sex options: `Female` · `Male` · `Prefer not to say`
- When sex is declined: `Ninety uses the higher of the two calorie floors when you'd rather not say. Erring high is the safe direction.`
- Footnote: `Used to work out a realistic starting point for you. Not shared with anyone.`

The activity levels each carry a line of their own — `Sedentary · Desk job, little
deliberate exercise` through `Very active · Training most days, or heavy physical
work` — because five words with no examples is five words nobody can choose
between.

**Age gate** (under 18 — §10)
- Title: `Ninety is 18+`
- Body: `Ninety isn't built for under-18s yet. Body-image and nutrition content for younger users needs safeguards we haven't built, and we'd rather say so than get it wrong.`
- Body 2: `If you're looking for support with eating or body image, Beat has a youth helpline: beateatingdisorders.org.uk`
- Button: `Sign out instead`
- **This is a hard stop with no bypass.** No "continue anyway."

> **Changed in P1-D.** It said `Close`. An iOS app cannot close itself — Apple
> rejects `exit()` and there is no supported equivalent — so `Close` would have
> been a button that does nothing on the one screen where the user has no other
> move. Signing out is the only honest action left, and it is not a bypass: the
> date of birth is on the profile, so signing back in lands here again.

**Starting weight** (added in P1-D — the band needs a weight and the deck had no
screen collecting one)
- Title: `Where you're starting`
- Body: `Ninety ranks on how much you improve against your own baseline, so it needs to know where the baseline starts.`
- Field: `Today's weight` · `kg`
- Footnote: `This becomes the first reading on your weight trend. You can add today's again later if you weigh yourself properly.`

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
- Value: `1,850 ±100 kcal`
- Body: `A band, not a number. Hitting exactly 1,847 isn't a real goal — landing in this range is.`
- Footnote: `Worked out from your height, weight, age and activity using the Mifflin-St Jeor equation. It's an estimate, and Ninety adjusts as it sees your real data.`

**Calibration explainer** (7 days — [ADR 0018](../../docs/decisions/0018-seven-day-calibration-window.md))
- Title: `The first week is calibration`
- Body: `Ninety watches your first 7 days to learn your baseline. You won't get a division until it closes — a rank based on two days of data would be meaningless.`
- Body 2: `Log as normally as you can. An unusually light week makes every week after it look worse by comparison.`
- Button: `Kick off` — it shares a screen with the band, and it is the action that finishes Pre-Season

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

## 2a. Settings

Four things on one screen, because they are the same obligation from four directions and
each of them was unreachable before P1-D. Presented as a sheet from Matchday's masthead:
§1.6 caps the app at three tabs, and §10 S6 wants the opt-out within two taps.

- Masthead: `Settings`
- Order, and it is load-bearing: **Competitive features** · **Support** · **Sync** ·
  **Your consent** · **Account**. The opt-out is first because two taps is only true while
  it is the panel you land on.

**Competitive features** — the S6 copy above, plus:
- When off: `Competitive features are off. You can turn them back on any time — your history is kept.`

**Support** — heading `Support`, then the §2 signposting block verbatim. Permanently
present, never behind a disclosure, never conditional on anything the app thinks it has
noticed.

**Sync** (added in P1-I)
- Heading: `Sync`
- Up to date: `Everything's on the server.` + `Ninety keeps a copy of what you log, so a lost or replaced phone doesn't take your days with it.` + `Last sent 12:04`
- Waiting: `12 changes waiting` + `Saved on your phone and readable right now. They'll go up on their own when there's a signal.` + `Send them now`
- Sending: `Sending…` — a sentence, never a spinner. §04's rule is that the UI never waits on the network, and a progress indicator is a small way of breaking it
- Stopped asking: `2 changes still here` + `The server didn't take these, so Ninety has stopped asking for now. Everything is still on this phone and nothing has been lost.` + `Try these again`
- No project in the build: `This build has no project in it.` + `Everything you log is saved on this phone and stays there. Nothing is being sent anywhere.`

Every line says the same two things — where the data is, and that it is safe. A queue that
has not drained is not a problem the user caused or can solve, so none of the copy asks them
to do anything about it and none of it is a warning. The register is the offline line in §4
below: *reassuring, not a warning.*

This is the only place in the app that mentions sync at all. A count of unsent rows on
Matchday would be the network leaking into the screen someone opens to log breakfast.

**Your consent**
- Heading: `Your consent`
- Body: `Both decisions are yours to change. Withdrawing is the same switch that gave it, in the same place.`
- The two switches are the consent screen's, unchanged — same headings, same wording.
- Note: `Ninety can't process health data without your consent, so withdrawing it brings back the consent screen. Nothing already logged is deleted.`

**Account**
- Heading: `Account`
- Body: `Signs you out on this phone. What's logged stays on the device and comes back when you sign in again.`
- Button: `Sign out`

Footer, on the screen itself: `Not a medical device. Ninety makes no medical claims and is
not a substitute for professional advice.`

**Not here yet.** Export and deletion (§7 below) are Phase 3 and the screen does not mention
them — a Settings screen listing a data-rights action that does nothing is worse than one
that does not list it.

---

## 3. Today dashboard

- Masthead meta: the date — `Thu 10 Sep`. No name, no time-of-day greeting; it ages badly and adds nothing
- Headline label, with room left: `STILL TO PLAY WITH` · value · `±100` · `KCAL`
- Headline label, past the band: `ABOVE YOUR BAND BY` · value — the figure keeps counting rather than clamping at zero
- Under it: `1,238 in · band 1,850 ±100`
- In band: `In your band` (`positive`)
- Above band: `Above your band` — **not** "over", **not** `critical`
- Below band: `Below your band` + `Eating well under your band slows progress more often than it speeds it up.`
- Pitch ends: `KICK OFF` · `THE BAND`
- Form ring: `FORM · 7 DAYS` · `5 of 7 days` + `Consistency is weighted 0.50. It's the half of the score you control.`
- Weight card: `WEIGHT · 7-DAY` · `78.4 kg` · `−1.2 kg`
- Macro split: `MACROS` · `From 3 of 5 items` — the coverage is on the panel, not in a footnote
- Team sheet: `TEAM SHEET` · `3 on · 1,238 kcal`, grouped `BREAKFAST` / `LUNCH` / `DINNER` (ADR 0022)
- Tier slot pre-Phase 2: `Ranking arrives in the next update`
- Tier slot during calibration: `CALIBRATING · 6 days to go` (of 7 — ADR 0018)

> **Corrected in P1-H.** This section wrote the band as `of 1,750–1,950 band`, which is the
> dash form the rest of the product rules out — in the one document that is meant to be the
> source for the strings that rule is about. `DESIGN.md` § Numbers is explicit and
> `SafetyCopyTests.rangesAreNeverDashed` is the check: a range is a figure and a tolerance.
> It reads `1,850 ±100` now.
>
> The headline label is a **deviation the build makes deliberately** and it is recorded in
> `DESIGN.md` rather than smoothed over here: the deck says `CALORIES REMAINING`, the build
> uses the artboard's `STILL TO PLAY WITH`. The world's vocabulary wins where it costs
> nothing, and this costs nothing.

**Empty states** (principle 5 — permission-denied and no-data are worded identically, because
the app genuinely cannot tell them apart):
- Food: `Nothing logged yet today.` + `Sub on`
- No band yet: `Finish Pre-Season to see your band.` — never a zero standing in for a number nobody computed
- Weight: `No weight yet.` + the trend panel says the reading is on The Run
- Macros: `No macros on today's logs.` + `Calories are what the band is made of, and every route records those. Macros come from the food's own figures, so a quick add by calories has none.`
- Form, nothing in the window: `0 of 7 days` + `Nothing logged in the last seven days.` — a count, never `you missed`
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
- Correction sheet, meal picker: `Which meal?` · `Breakfast` / `Lunch` / `Dinner` + `Ninety reads this off the time you logged it. Move it if that is wrong.`

That last note says what the app *did* rather than asking the user to do anything. The slot is
derived from `logged_at` for almost every row (ADR 0022), so the right answer is already
selected and the control is there for the night shift and the very late dinner.

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
- Singular on the last day: `CALIBRATING · 1 day to go`

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
