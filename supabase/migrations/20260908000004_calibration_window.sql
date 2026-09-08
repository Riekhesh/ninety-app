-- ─────────────────────────────────────────────────────────────────────────────
-- 004 · The calibration window is seven days
--
-- ADR 0018. Migration 001 was written against §2.3's fourteen and is applied to
-- the live project, so it is left exactly as it was: an applied migration is a
-- record of what ran, and editing one to make a comment read better is how a
-- schema and its history stop agreeing.
--
-- Nothing about the column changes. `calibration_completed_at` still means the
-- same thing — null while the window is open, stamped when it closes — and the
-- length of the window was never encoded in the schema, because it is a product
-- decision rather than a constraint. What changes is the comment, which is the
-- only place the number appears in the database, and which now points at the
-- ADR rather than restating a figure that can move again.
--
-- No RLS change: the column is on `profiles`, which is already covered.
-- ─────────────────────────────────────────────────────────────────────────────

comment on column profiles.calibration_completed_at is
  'Null while the calibration window is still open; stamped when it closes. '
  'The window is seven days from the day Pre-Season completes (ADR 0018 — it '
  'was fourteen in the brief). No tier is assigned until it closes; the app '
  'shows "CALIBRATING · N days to go" instead. Seven CALENDAR days, not seven '
  'logged days: a countdown a user can shorten by logging is a streak mechanic, '
  'which §10 rules out.';
