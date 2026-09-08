# ADR 0017 — Health consent is a separate record, and the app will not start without it

**Status:** Locked
**Date:** 2026-09-07
**Phase:** 1
**Brief reference:** §10
**Related:** `docs/safety/safety-requirements.md` § Data protection

## Context

UK GDPR Article 9 makes health data special category data: processing it needs
**explicit** consent and a documented lawful basis. Everything Ninety exists to
do is Article 9 processing — food logs, weights, and whatever it reads from
Apple Health.

`docs/safety/safety-requirements.md` already names the test
(`test_health_consent_is_separate_from_terms_acceptance`) and migration 001
already ships two columns, `terms_accepted_at` and `health_consent_at`, with a
comment saying why. What was never decided is what the app does when one of them
is given and the other is not — and that turns out to be the whole question.

The tempting shape is one screen, two tick boxes, one "Continue" button that
writes both. It satisfies a reading of the requirement and fails the point of
it: consent that was only ever given as half of a pair cannot be withdrawn on
its own, and after the fact nobody can tell which of the two the user actually
agreed to.

## Decision

**Two decisions, two calls, two columns, two timestamps — and no API anywhere
that records both.**

`ConsentRecorder` has `acceptTerms(at:)` and `consentToHealthData(at:)`, plus a
withdrawal for each. Nothing takes a "both" flag. The only thing that reads them
together is `ConsentStatus`, which reports and never sets, and whose
`allowsHealthProcessing` is true for exactly one of its four states.

Three consequences, all deliberate:

1. **Either can be given without the other**, and the tests assert it in both
   directions. That is what makes them two decisions rather than one decision
   rendered as two controls.

2. **Both are reversible on the consent screen itself.** A tick that cannot be
   un-ticked is a gate, and consent given at a gate is not freely given.

3. **The app does not start on a partial consent.** No tabs, no logging, nothing
   written beyond the profile row holding the consent record itself.

## Why refusing to start is the right answer

The usual move — run in a degraded mode without the health features — is wrong
here, and for a different reason than it is wrong for S6.

The S6 competitive opt-out **must** leave a fully useful tracker, because an
opt-out that cripples the app is a threat rather than a choice. Health consent
is the opposite case: there is no version of Ninety that is not processing
health data. A "limited mode" would either be an empty shell pretending to be a
product, or — much worse — a tracker quietly logging food without the consent
that makes logging food lawful.

So the screen offers the honest alternative instead: **sign out**. Not a
force-quit, not a dead end. Declining is a real answer and it has a button.

## Withdrawal is not erasure

`withdrawHealthConsent()` clears the timestamp and deletes nothing. They are
separate rights and conflating them punishes the user for exercising one — stop
processing my data and lose my history is not a choice anyone should have to
make. Erasure is Phase 3's deletion path, and
`test_deletion_removes_all_rows_across_all_tables` is already written down
waiting for it.

## Trade-off accepted

**One more screen before the 21-day clock can start.** Shown once, and it sits
where onboarding already had to be.

**Withdrawal has a screen only before consent is complete.** The recorder
supports withdrawing either consent at any time and the consent screen exposes
both, but once both are given the shell moves on and there is no Settings
surface yet to withdraw from — Ninety has no Settings screen at all until S6's
opt-out switch lands in P1-D. Until then the copy deliberately describes what
withdrawal *does* rather than promising where to find it. **This is a gap, not a
subtlety**, and P1-D closes it: the same screen that carries the S6 switch and
S7's signposting carries this.

**The record is local until P1-I.** Consent is written to SwiftData and enqueued
in `sync_outbox` like every other write (ADR 0005), and nothing drains that
outbox yet — so today a reinstall asks again, and the second timestamp replaces
the first. Right by construction once sync lands, and worth knowing until it
does: the consent that authorises Phase 1's processing is currently evidenced on
one device only.

**A record of consent, not a record of what was consented to.** There is no
consent *version*, so a materially changed privacy policy cannot be told apart
from the original by looking at the row. Fine for one user who wrote the policy;
before the first external tester it needs a version column, and that is a Phase
3 line item rather than a discovery.

## Reversal trigger

- A qualified reader — the clinician review, or anyone with a data-protection
  background — says the separation as built does not meet Article 9's "explicit"
  bar. That is a rewrite of this file, not an argument.
- The consent screen measurably becomes the place people abandon the app, which
  would mean the wording rather than the structure needs work.
- Phase 3 adds a privacy policy that can change under a signed-in user, at which
  point "consented once" stops being enough and a version column is required.
