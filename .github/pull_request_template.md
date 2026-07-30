<!--
Solo project, so this template is a checklist for you rather than a form for a
reviewer. Its job is to make you stop for ninety seconds before merging.
Delete sections that genuinely do not apply.
-->

## What and why

<!-- The diff says what changed. Say why, and cite the brief section (§1.3, §2.3). -->

## Phase

<!-- 0 / 1 / 2 / 3 / 4 / 5 -->

## Scope check

> Does this trace back to the cover thesis?
> *Notch ranks users on rate of improvement and consistency relative to their own
> baseline — not absolute performance.*

- [ ] Yes, directly
- [ ] Yes, it feeds data to the ranking engine
- [ ] No — and I have written down why it is in anyway

## Verification

- [ ] `swiftlint` clean
- [ ] `swift test` passing
- [ ] Tested on a physical device (required for anything touching HealthKit)
- [ ] Tested in airplane mode (required for anything that logs — the UI must
      never wait on the network, §04)

## Safety review (§10)

Only if this touches onboarding, targets, scoring, streaks, tiers, or any
user-facing string:

- [ ] No punishment framing in any new string — regression is a reset, not a failure
- [ ] Calorie floor and goal-weight BMI validation still enforced
- [ ] Nothing rewards losing weight faster than the safe rate
- [ ] The competitive/social opt-out still disables everything it claims to

## Data protection (§10)

Only if this touches health data, storage, or export:

- [ ] RLS policy exists and was tested with a second account
- [ ] Data export still includes this data
- [ ] Account deletion still deletes this data

## Notes for the write-up

<!-- Anything here that becomes a paragraph in the report or an interview answer.
     Measured numbers, exploits found, decisions reversed and what changed them. -->
