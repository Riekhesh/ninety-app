# ADR 0016 — Sign in with Apple is the only way in

**Status:** Locked
**Date:** 2026-09-07
**Phase:** 1
**Brief reference:** §1.1, §04, §10

## Context

P1-C has to produce a signed-in user before anything else in Phase 1 can write a
row: every table is keyed on `auth.users.id`, and every RLS policy in migration
002 compares against `auth.uid()`. Until that id exists there is nowhere to put a
food log.

The question is not *whether* to offer Sign in with Apple. Apple's App Store
Review Guideline 4.8 makes it mandatory the moment an app offers any other
third-party login, so the real options were:

1. **Sign in with Apple only.**
2. **Sign in with Apple plus email/password**, which Supabase gives for free.
3. **Anonymous sessions now, identity later** — Supabase supports these, and it
   would let the 21-day clock start without an account at all.

Option 3 is the interesting one and it is why this is written down rather than
assumed. Twenty-one consecutive days is the only exit criterion no amount of
effort compresses, and anything that starts the clock sooner is worth taking
seriously.

## Decision

**Sign in with Apple, through Supabase Auth's id-token exchange, and nothing
else.** No email/password, no anonymous sessions, no other provider.

Three things follow from it, and each is a decision in its own right:

1. **No scopes are requested.** `requestedScopes = []`. Apple offers name and
   email exactly once, on the first authorisation, and Ninety needs neither —
   the user id is what every row is keyed on. A field never collected cannot go
   stale behind Hide My Email, cannot leak, does not appear on an Article 9
   export, and does not have to be declared in the App Privacy labels.

2. **The nonce is generated raw and hashed once.** Apple's request carries the
   SHA-256; Supabase is handed the raw string and hashes it again to compare.
   The pair lives in `AppleIdentity`, and `SessionController` owns both halves,
   because the failure mode of getting them the wrong way round is a flat
   invalid-token rejection whose message never mentions the nonce.

3. **The SDK owns the session.** `supabase-swift` persists to the Keychain and
   refreshes in the background; the app has no refresh loop, no `UserDefaults`
   mirror of "is somebody signed in", and no retry. A second source of truth for
   a session is a race, and a second refresh loop is two.

`AuthServiceProtocol` is the boundary. `SupabaseAuthService` is the only file in
the app that imports the SDK.

## Why not anonymous sessions

They would start the clock sooner, and they would cost it back later. An
anonymous user has real rows against a real id, so upgrading them to an Apple
identity is a data migration on a live device holding health data — the exact
"genuinely bad afternoon" §1.1 describes for retrofitting RLS, in a place with
fewer tools to check the result. And the days most likely to be lost are the
first ones, which are the calibration window.

The measured cost of not doing it is one screen with one button on it, shown
once. That is not what is standing between the repo and day 1.

## Why not email/password too

Every credential path is a support surface: reset flows, rate limiting, breach
handling, and a password field that has to be right on the first screen a user
ever sees. For a single-user Phase 1 it buys nothing, and 4.8 means it cannot
replace Sign in with Apple, only sit beside it.

It is also not a door that closes. Adding a provider later adds it *next to*
Apple, with no account-linking migration and no "you previously signed in with
Google" state, precisely because Apple is already there.

## Trade-off accepted

**A paid Apple Developer Programme membership is now a hard dependency**, on the
critical path rather than beside it. Phase 0 spent three weeks waiting on
enrolment; the entitlement is available now, and this makes it load-bearing.

**iOS only, in effect.** Sign in with Apple has a web flow, but a session
started this way is practically an Apple-device session. ADR 0001 already
committed to native iOS, so this narrows nothing that was open.

**Signing out does not erase the local store.** The session goes, the SwiftData
rows stay. That is deliberate — signing out on a shared phone should not destroy
three weeks of logs — and it means device-level erasure is a genuinely separate
path, which is Phase 3's deletion work. Recorded here so it is a decision rather
than an omission.

## Reversal trigger

- Apple rejects the app for something in the sign-in flow, or changes 4.8 such
  that a second provider becomes cheaper than this one.
- A real user cannot sign in and the cause is the Apple flow rather than the
  code — a device without an Apple Account, or a family-managed one. One report
  is enough: the app is unusable for them, and an email fallback is a day.
- The 21-day clock is blocked on account creation rather than on the app being
  built, which would make anonymous sessions worth the migration after all.

Record the specific rejection or the specific user report if this is reversed.
