-- ─────────────────────────────────────────────────────────────────────────────
-- 007 · Meals get real slots
--
-- ADR 0022. `First Half` and `Second Half` were derived from `logged_at` and
-- stored nowhere, which was the right trade while Sub On's Today list was the
-- only thing reading them. Matchday's team sheet is where two buckets stopped
-- being enough, so the slot becomes a value the user can correct — and the
-- moment it can be corrected it has to be stored.
--
-- **Nullable, and null is not missing data.** Null means "derive it from
-- logged_at", which is what every row written before this migration means and
-- what almost every row written after it will mean too: no logging route asks
-- the question, the app derives an answer, and the column is only filled when
-- the user says the derivation got it wrong. A `not null default` would have
-- been the other shape and it is worse in both directions — it would force a
-- backfill that guesses at every existing row using today's boundaries, and it
-- would make "the app worked this out" indistinguishable from "the user said
-- so", which is the one distinction the column exists to carry.
--
-- **No RLS change.** `food_logs` already has the four policies from 002 and they
-- are row-level, not column-level, so a new column on an existing table is
-- covered the moment it exists. Worth stating rather than assuming: the exit
-- criterion is RLS on every table, and a migration that adds a column without
-- saying which policies cover it is how that stops being checkable.
--
-- **The 48-hour lock covers it too**, for the same reason: `food_logs_update_
-- before_lock` gates the whole row, so correcting a slot after the window has
-- closed is refused exactly like correcting a portion. That is deliberate —
-- §2.3 locks the log, and the slot is part of the log.
-- ─────────────────────────────────────────────────────────────────────────────

create type meal_slot as enum ('breakfast', 'lunch', 'dinner');

alter table food_logs add column meal_slot meal_slot;

comment on column food_logs.meal_slot is
  'Null means derive the slot from logged_at in the user''s own calendar '
  '(breakfast before 11:00, lunch before 16:00, dinner after) — ADR 0022. A '
  'value is present only where the user corrected the derivation, so null and '
  'a value are different statements: "the app worked this out" and "the user '
  'said so". Deriving in the user''s calendar rather than off a UTC offset is '
  'what stops a late London dinner landing in the next morning for half the '
  'year.';
