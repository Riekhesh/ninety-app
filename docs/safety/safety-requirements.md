# Safety requirements

> §10: *"This is the most important page in the document."*
>
> *"A gamified calorie app with streaks and competitive ranks can actively reinforce
> disordered eating. This is a real, well-documented harm. Apple has rejected apps
> over it. And you will have real users, some of whom will be vulnerable in ways you
> cannot see from a dashboard."*

§10 gives seven requirements as prose. This file turns each into a **rule with a
number and a test name**, because a requirement you cannot test is a requirement you
will discover you did not implement.

All seven are built in **from Phase 1**, not bolted on before launch. §10: *"Building
these in from the start costs a couple of hours. Retrofitting them after someone has
been harmed costs considerably more."*

---

## ⚠️ These numbers need a clinician

The thresholds below come from widely-published UK public-health guidance (NHS, NICE)
and are the values a reasonable non-expert would arrive at. **They have not been
reviewed by anyone clinically qualified, and I am not qualified to set them.**

- Before Phase 3 external testers, get them reviewed. A GP, a registered dietitian, or
  a university health-sciences contact. This is a half-hour conversation, not a
  research project.
- Record who reviewed them and when, in the [review log](#review-log) at the bottom of
  this file.
- Until then, the app is used by one person who knows the limitation.

The *structure* here — floors, ceilings, refusals, opt-outs — is right regardless of
whether a specific number moves.

### The pack to send them

**[clinician-review-pack.md](clinician-review-pack.md)** is this file rewritten for
someone who has never seen the repo: self-contained, ~30 minutes, and it asks
**specific numbered questions** rather than "does this look alright?" A reviewer who is
doing you a favour needs to know exactly what is being asked and exactly what is not —
it says plainly that it is not asking them to endorse the app or take responsibility
for it, and offers to record them anonymously.

**Who to ask, roughly in order of how easy they are to reach:**

| Who | How |
|---|---|
| **A university contact** — health sciences, nutrition, sports science, or dietetics | The easiest door. Email a lecturer directly; a 30-minute review of a student project is a normal ask, and they will often hand it to a colleague who is a better fit. |
| **A registered dietitian** | The best fit for S1–S3 specifically. The BDA's "find a dietitian" directory lists freelancers; a short paid consultation is a legitimate way to do this and is not expensive. |
| **A GP you already have a relationship with** | Good on S4 and S7, less specific on the calorie numbers than a dietitian. |
| **Beat** (the eating disorder charity) | Will not review your thresholds, but their published guidance for app developers is worth reading before you send the pack — it may answer Q5.3 on its own. |

You do not need all of them. **One qualified reader is the difference between "numbers
from public guidance" and "numbers a professional looked at"**, and that is the
sentence you want to be able to write in Phase 3 and in the write-up.

---

## S1 · Hard minimum calorie floor

**Rule.** The computed daily target may never fall below the floor, whatever the user
asks for.

| Sex | Floor | Basis |
|---|---:|---|
| Female | **1,200 kcal/day** | Below this, meeting micronutrient requirements from food is impractical; commonly cited as the point where medical supervision is advised |
| Male | **1,500 kcal/day** | Same reasoning, higher baseline requirement |
| Not specified / prefer not to say | **1,500 kcal/day** | Use the higher floor when unsure — erring high is the safe direction |

**Behaviour.** Clamp, do not reject. If Mifflin-St Jeor minus the requested deficit
lands below the floor, set the band at the floor and say so. Then offer the lever that
actually helps — a slower rate of loss — rather than leaving the user stuck.

**Interacts with S3.** A user who wants 1 kg/week at a low body weight will hit this
floor. The correct response is to reduce the *rate*, not to sit at the floor
indefinitely: the floor is a hard stop, not a target.

```
test_calorie_target_never_below_floor_female
test_calorie_target_never_below_floor_male
test_unspecified_sex_uses_higher_floor
test_floor_breach_surfaces_slower_rate_option
test_floor_applies_after_deficit_not_before
```

---

## S2 · Goal weight validation against healthy BMI

**Rule.** Reject a goal weight whose BMI would be **below 18.5** for the user's
height.

```
BMI = kg / (m × m)
minimum acceptable goal weight = 18.5 × height_m²
```

For 1.75 m that is 56.7 kg; the app refuses anything lower and says what the lowest
acceptable value is, so the user is not left guessing.

**Deliberately asymmetric.** There is no upper limit on goal weight. A user wanting to
*gain* to a BMI of 27 is not doing something the app should block — the harm this
requirement addresses runs in one direction.

**Reject, do not clamp.** Unlike S1, silently substituting a different goal would be
dishonest about what the app is tracking toward.

```
test_goal_weight_below_bmi_18_5_is_rejected
test_goal_weight_at_bmi_18_5_is_accepted
test_rejection_states_the_minimum_acceptable_weight
test_no_upper_bound_on_goal_weight
test_bmi_uses_metres_not_centimetres        // the classic 10,000× bug
```

---

## S3 · Rate-of-loss ceiling — safety *and* scoring

**The one that is genuinely elegant.** §10: *"The engine should not reward losing
weight faster than a safe rate. Score the appropriate rate highest, not the maximum —
this is a place where the ranking design and the safety design happen to align
perfectly."*

**Rule.** The ceiling is the lower of:

```
ceiling = min(1.0 kg/week, 1% of current body weight per week)
```

For 70 kg that is 0.70 kg/week. For 120 kg it is 1.0 kg/week (the absolute cap binds).

Selectable rates in onboarding: **0.25 / 0.5 / 0.75 kg per week**, filtered to those
at or below the user's ceiling. There is deliberately no "maximum" option.

**Two enforcement points, and both are needed:**

1. **Onboarding** — cannot select a target rate above the ceiling.
2. **The scoring engine** — progress score **peaks at the user's target rate and
   declines above it.** Losing 1.5 kg in a week scores *lower* than losing 0.5 kg
   when 0.5 was the target.

Point 2 is the part that matters. A ceiling only in onboarding is advice; a ceiling in
the score is an incentive. Without it, the app's headline metric rewards exactly the
behaviour §10 exists to discourage — and users optimise for the metric, not the
onboarding copy.

**Shape.** Score rises to 1.0 at target rate, then falls away above it. Not a cliff
(a hard cutoff makes a good week look like a bad one for being slightly over) — a
smooth decline. Specified properly in Phase 2 alongside the rest of the maths.

```
test_target_rate_scores_higher_than_double_target_rate
test_progress_score_peaks_at_target_rate
test_progress_score_declines_monotonically_above_ceiling
test_rate_ceiling_is_one_percent_bodyweight_for_light_user
test_rate_ceiling_caps_at_1kg_for_heavy_user
test_onboarding_hides_rates_above_ceiling
```

---

## S4 · Age gate

**Rule.** Date of birth is collected in onboarding. **Under 18 is a hard stop with no
bypass** — no "continue anyway", no parental-consent path.

§10: *"The safeguarding considerations for minors and body-image content are
substantial and well beyond what a solo v1 should attempt."* That is the honest
reason, and the copy says it (`design/spec/04-copy-deck.md`) rather than pretending it is a legal
technicality.

The rejection screen signposts Beat's youth helpline. A user turned away should not
leave with nothing.

**Computed on the actual date**, not a year subtraction — someone turning 18 tomorrow
is 17 today. `AgeGate` delegates to `Calendar.dateComponents` rather than doing the
arithmetic itself, because hand-rolled versions are what get the boundary wrong.

> **One open question for the review, found by running the tests.** For a birthday on
> **29 February**, `Calendar` treats 28 February as the anniversary in a non-leap year,
> so the gate opens on 28 February rather than 1 March — the date more commonly used for
> attaining an age. It affects one birthday in four years and it errs a day **early**,
> which is the direction §10 would rather it did not. Making it late needs a leap-day
> special case, which is the hand-rolled arithmetic this rule avoids everywhere else.
> Left as the calendar's answer, recorded here, and worth a sentence to whoever reviews
> these numbers. `leapDayBirthdayIsHandledByTheCalendar` is the test that pins it.

```
test_under_18_is_blocked
test_exactly_18_today_is_allowed
test_17_years_364_days_is_blocked
test_no_bypass_path_exists_from_the_age_gate
test_age_gate_screen_includes_support_signposting
```

---

## S5 · No punishment framing anywhere

**Rule.** No user-facing string frames a shortfall as failure. Regression is a reset.

**Enforced three ways:**

1. **`no_punishment_framing`** in `.swiftlint.yml`, severity **error** — 17 banned
   phrases, matched against string literals. Fails the build.
2. **`../../design/spec/04-copy-deck.md`** — every string written out, with the rewrite rule
   and a second list of phrases that need human judgement (`cheat meal`, `burn off`,
   `earn it`, `on track`).
3. **PR template** — an explicit safety-review checkbox on anything touching copy.

**Also structural, not just verbal:**

- **No error colour exists for logged intake.** Absent from the token set on purpose.
  A designer reaching for "the red one" for over-budget will not find one.
- A missed day is an **empty** mark, never crossed out.
- No streak-loss animation.
- Losing a tier always states the way back: *"Gold is four consistent days away."*

```
test_no_banned_phrase_in_any_localised_string
test_tier_regression_copy_states_the_path_back
test_missed_day_renders_empty_not_negative
test_over_band_state_does_not_use_critical_colour
```

---

## S6 · Always-available competitive opt-out

**Rule.** A visible switch disables **every** competitive and social feature —
without disabling the app's core usefulness.

| Off | Still works |
|---|---|
| Tier badges and the Rank tab | Food logging, all three paths |
| Weekly score computation | Weight trend and EWMA chart |
| Rank-up notifications | HealthKit sync |
| Streaks | Data export and deletion |
| Friend leaderboards (Phase 4) | The Today dashboard |

**The critical property is the right-hand column.** An opt-out that leaves a crippled
app is not an opt-out — it is a threat. Someone who turns competition off must still
have a fully useful food and weight tracker, or they will simply delete the app,
which is the outcome this requirement exists to prevent.

Reachable in **at most two taps** from the Today screen. Not buried. History is
preserved and the switch is reversible.

**Built in P1-D.** The two taps are Matchday's masthead control and the switch itself, and
the switch is the first panel in Settings — which is the part that can regress, so
`SettingsSection` declares the order and `CompetitiveOptOutTests` asserts it. The
right-hand column above is `CompetitiveFeatures`' unconditional half: each promise is a
separate property returning a constant, so a later epic that starts gating logging on the
opt-out has to edit a line whose comment says why it must not.

```
test_opt_out_hides_rank_tab
test_opt_out_stops_score_computation
test_opt_out_preserves_food_logging
test_opt_out_preserves_weight_trend_and_healthkit_sync
test_opt_out_is_reachable_in_two_taps
test_opt_out_is_reversible_and_preserves_history
```

---

## S7 · Signposting

**Rule.** Where patterns suggest it may help, surface UK support resources.

| Organisation | Contact |
|---|---|
| Beat | 0808 801 0677 · beateatingdisorders.org.uk |
| National Alliance for Eating Disorders | eatingdisorderinfo.org |

**Always available** in Settings. **Built in P1-D**: a permanent `Support` section, never
behind a disclosure and never conditional on anything the app thinks it has noticed. The
age-gate screen carries Beat's youth helpline too, because that is the one screen a user
leaves because Ninety turned them away.

**Additionally surfaced** — once, non-modally, dismissible — when any of these hold. **None
of this is built**; it is a Phase 3 gate and the four triggers below have no code behind
them:

| Trigger | Threshold |
|---|---|
| Sustained loss above the ceiling | > S3 ceiling for 3 consecutive weeks |
| Sustained intake near the floor | Within 5% of the S1 floor for 14 consecutive days |
| Repeated goal-weight attempts below healthy BMI | 3 or more attempts (S2 rejections) |
| Logging at the floor with high activity | Floor-adjacent intake + activity in the top decile of their own history |

**Never modal, never repeated, never accusatory.** A dialogue the user cannot dismiss
is coercive, and a repeated one gets the app deleted. Offer once, keep it in Settings.

**No diagnosis.** The app does not detect eating disorders, must not imply it can, and
the copy says only *"if this is feeling difficult, these people help"* — which is true
and within what the app can honestly claim.

```
test_signposting_always_available_in_settings
test_signposting_surfaces_after_three_weeks_above_rate_ceiling
test_signposting_surfaces_after_fourteen_days_at_calorie_floor
test_signposting_is_dismissible
test_signposting_does_not_repeat_within_30_days
test_signposting_copy_contains_no_diagnostic_language
```

---

## Data protection (§10 · UK GDPR Article 9)

Health data is **special category data** under Article 9 — explicit consent and a
documented lawful basis. Required **before the first external tester**, not before
launch.

| Requirement | Where |
|---|---|
| Privacy policy live | GitHub Pages, free and adequate |
| Explicit consent for health data | **Built, P1-C.** Two columns, two calls, two timestamps, and no API that writes both — [ADR 0017](../decisions/0017-health-consent-separate-from-terms.md). A partial consent does not start the app; the honest alternative on offer is signing out |
| Working data export | Settings → Export. JSON: profile, food logs, weights, health samples, weekly scores |
| Genuine account deletion | Settings → Delete. Actually deletes, including Storage objects. Not a soft-delete flag. |
| Accurate App Privacy labels | App Store Connect. Under-declaring health collection is a fast rejection (§3.2) |

```
test_export_includes_every_table_holding_user_data
test_deletion_removes_all_rows_across_all_tables
test_deletion_removes_storage_objects_for_meal_photos
test_deletion_is_not_a_soft_delete_flag
test_health_consent_is_separate_from_terms_acceptance
```

**What P1-C left open, and P1-D closed.** Consent could be withdrawn on the consent screen
and nowhere else, because Ninety had no Settings screen — so once the app had started,
neither switch was reachable again and the copy deliberately said what withdrawal *does*
rather than where to find it.

It is now `Settings → Your consent`: **the same two switches, in the same shape as the
consent screen**, not a buried "manage data" link and not behind a confirmation dialogue.
Withdrawal that is harder than giving means the consent was never freely given, so the two
are deliberately the same act. Withdrawing health consent dismisses Settings and puts the
consent gate back up — the app has just lost the lawful basis for the screen underneath it,
and leaving the user on it would be processing without one. The consent copy now names
Settings, because the screen it names exists.

The deletion test is the one that will actually catch something. Add a table in Phase
2 and forget to add it to the delete path, and the test fails — which is the entire
reason to write it as a test that enumerates tables rather than a checklist item.

---

## No medical claims

§10 lists App Store rejection as a live risk: *"Health apps face stricter review. No
medical claims anywhere in copy."*

**Banned:** any claim to diagnose, treat, prevent or cure; "clinically proven";
"doctor recommended"; specific health-outcome promises; "should" in a prescriptive
sense.

**Allowed:** describing what the app does — *"tracks what you log"*, *"scores your
consistency"*, *"shows your weight trend"*.

Footer, everywhere it fits: *"Not a medical device. Ninety makes no medical claims and
is not a substitute for professional advice."*

---

## Phase gate checklist

**Phase 1 — build it in, do not defer it.** All seven built in P1-D and **closed on 8
September**: compiled, 104 tests green, and the flow walked on a real device. The ticks are
on executed tests rather than on written ones — a gate whose test has not run is a gate
nobody has checked, and this list stayed unticked for the length of the branch for exactly
that reason.

- [x] S1 calorie floor, clamping with the slower-rate offer — `EnergyTarget`, 5 named tests
- [x] S2 goal-weight BMI validation, rejecting — `GoalWeight`, 5 named tests
- [x] S3 rate ceiling enforced in onboarding — `LossRate`, 3 named tests. **The scoring half is Phase 2 and is the half that matters**; this tick is the onboarding half only
- [x] S4 age gate, hard stop, with signposting — `AgeGate`, 5 named tests. Walked on device: blocked, signed out, signed back in, still blocked. One open boundary question below
- [x] S5 SwiftLint rule active and copy deck followed — the lint half has run since Phase 0; P1-D added the structural half (`Tone`, `BandState`, `DayMark`) and its tests
- [x] S6 opt-out switch, with core usefulness intact — `CompetitiveFeatures`, 6 named tests, every promise asserted under both states of the switch
- [x] S7 signposting present in Settings — `Signposting`, permanent section, no diagnostic language. **The pattern triggers are Phase 3** and have no code behind them

**The one thing S4's tick does not cover**, because it was found by the test run rather than
settled by it: the leap-day boundary in the note under S4 above. The gate opens a day early
for a 29 February birthday, and that is recorded as a question rather than a defect.

**Phase 2 — the scoring half of S3:**
- [ ] Progress score peaks at target rate and declines above the ceiling
- [ ] Named tests for every S3 assertion above

**Phase 3 — before the first external tester:**
- [ ] Thresholds reviewed by someone clinically qualified — send
      [clinician-review-pack.md](clinician-review-pack.md), then record the result in
      the [review log](#review-log)
- [ ] Privacy policy live
- [ ] Export and deletion working and tested
- [ ] App Privacy labels accurate
- [ ] S7 pattern triggers implemented and tested

---

## Review log

| Date | Reviewer | Role | Changed |
|---|---|---|---|
| 2026-07-30 | — | initial draft, **not clinically reviewed** | S1–S7 numbers set from public UK guidance |

