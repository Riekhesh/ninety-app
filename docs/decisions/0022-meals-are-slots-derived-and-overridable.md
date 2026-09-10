# 0022 · Meals are real slots — derived by default, stored when corrected

**Status:** Locked · **Phase:** 1 · **Date:** 10 September 2026

## Context

`docs/phase-1/README.md` parked one product question for P1-H, in as many words:
*"whether Ninety grows real meal slots (breakfast / lunch / dinner) or keeps First Half /
Second Half."* It was parked deliberately — *"a decision to make with the dashboard in
front of you rather than a patch"* — and P1-H is that dashboard.

**What existed.** `MealPeriod` was two cases, `firstHalf` and `secondHalf`, changing over
at midday in the user's own calendar. It was derived from `logged_at` and stored nowhere:
no column, no migration, no line in `check_schema_parity.py`. Both `SubOnModel` and
`TodaySection` carried the same note — *"this is deliberately not a down-payment"* on real
slots — and that note was right for what the halves were being asked to do. Sub On's Today
list is a correction surface you open standing where you did the logging, and two buckets
are enough to find the row you just tapped twice.

**What changed.** Matchday's team sheet is not that. It is the shape of the day, under the
figure the day adds up to, on the screen somebody opens for fifteen seconds to see how
they are doing — and `SECOND HALF · 778` answers no question anybody has. Worse, it
answers *less* than the timestamps it was derived from: the artboard's own sample day has
a flat white at 09:15, a chicken salad at 13:05 and a yogurt at 16:20, and grouping those
into two halves puts lunch and an afternoon snack in the same bucket as dinner while
telling you nothing you could not read off the clock.

So the question is not "are three labels nicer than two". It is whether the grouping on
the dashboard is a thing the user recognises as their day.

## Decision

**Three slots — breakfast, lunch, dinner — as a nullable Postgres enum on `food_logs`,
derived from `logged_at` when the column is null and stored only when the user corrects
it.**

Four parts, and each is load-bearing:

**1. The slot is derived by default.** `MealSlot.of(_:calendar:)` reads the hour in the
user's own calendar: breakfast before 11:00, lunch before 16:00, dinner after. No logging
route asks which meal it is, so logging costs exactly the number of taps it did
yesterday. **That is the clock's constraint, not a convenience** — the 21 days have been
running since 9 September, and a decision that added a required field to the write path
would be spending the one thing this phase cannot compress on a label.

**2. The column exists so the derivation can be wrong.** Migration 007 adds
`food_logs.meal_slot meal_slot` — nullable. Null means "read it off `logged_at`"; a value
means the user moved it. A night shift, a very late dinner, a breakfast eaten at four in
the afternoon: the boundaries are the ones that are wrong least often, not the ones that
are right for everybody, and there has to be somewhere for the difference to live.

**3. A slot is stored only where it disagrees with the derivation.** The correction sheet
hands the repository whatever its picker holds, and
`SwiftDataFoodRepository.update(_:grams:kcal:mealSlot:at:calendar:)` writes the column
only if that differs from `MealSlot.of(loggedAt)`. So correcting a portion without
touching the picker writes nothing, and re-picking the slot that was already showing
clears the column rather than filling it. **Null keeps meaning what it means**, which is
the whole reason the two states are worth distinguishing.

**4. Null is never backfilled.** Every row written before migration 007 means "derived",
which is the same thing every row written after it will mean. A backfill would guess at
three weeks of somebody's history using today's boundaries and record the guess as if the
user had made it.

**Three values, and no `snack`.** Adding a fourth later is `alter type meal_slot add value
'snack'` and one case in `Domain.swift`; removing one is a data migration across
everybody's history. The enum starts at what the decision asked for rather than at what
somebody might want, and the asymmetry is the reason.

## Consequences

- **`MealPeriod` is deleted**, not deprecated. It had one job and `MealSlot` does it.
- **The local store goes to V2.** `NinetySchemaV2` adds one optional property to one
  model, with a lightweight migration stage. This is the first schema change to land on a
  phone that already holds logged days, which is precisely the case `NinetySchemaV1`'s own
  note was written for — and it is the cheapest shape such a change can have, because
  nothing needs backfilling.
- **`check_schema_parity.py` now reads every migration, not just 001.** It could not see
  `meal_slot` otherwise and would have reported the drain as sending a column that does
  not exist. The schema stopped being one file with this migration, and the checker had
  been assuming it was.
- **§2.3's 48-hour lock covers the slot**, because the lock is on the log and the slot is
  part of the log. `food_logs_update_before_lock` enforces the same thing server-side.
  Correcting a slot on a three-day-old log is refused exactly like correcting a portion.
- **RLS is unchanged and that is checked rather than assumed.** The four `food_logs`
  policies from migration 002 are row-level, so a new column is covered the moment it
  exists.
- **The wire sends `null` rather than omitting the column.** An upsert that omitted it
  would leave whatever the server holds, so a correction handing a row back to the
  derivation could never clear it.

## What was considered and rejected

**Keeping First Half / Second Half.** The status quo, and it costs nothing. Rejected
because the dashboard is where the halves stopped paying for themselves: they are a
grouping the user did not ask for, cannot correct, and learns nothing from.

**Three slots, still purely derived — no column.** Tempting, because it is a one-line
change and keeps the schema still. Rejected because it is not a decision, it is a
relabelling: the halves became thirds and the app still tells a night-shift worker they
ate dinner for breakfast, with no way to say otherwise. If the slot can never be wrong in
the user's eyes it does not need to be stored; the moment it can, it does.

**A required slot on every log — a picker on the write path.** The shape most trackers
have. Rejected on the clock: it puts a question in front of every meal to improve a
grouping on a screen the user is not currently looking at, and the friction lands on the
one metric Phase 1 exists to produce. §2.2 weights consistency at 0.50 precisely because
showing up *given the friction* is the thing being measured — adding friction to improve
a label would be measuring the wrong app.

**`not null default 'lunch'` with a backfill.** Rejected twice over. It would guess at
every existing row using boundaries chosen today, and it would make "the app worked this
out" indistinguishable from "the user said so" — which is the one distinction the column
is for.

**Deriving on the server instead.** Postgres could compute the slot from `logged_at` in a
generated column. Rejected for the reason migration 001 gives for `locked_at` being a
trigger rather than `generated always as`: adding an interval to a `timestamptz` depends
on the session `TimeZone`, so the derivation is not immutable — and the calendar that
matters is the user's phone's, which the database does not have.

## How this could be wrong

**Eleven and four are not everybody's boundaries**, and nothing in the app learns
otherwise. Somebody who eats at 10:30 and 17:00 every day will correct two rows a day
until they stop bothering. The honest answer if that happens is per-user boundaries or a
learned default, and both are Phase 2 work with a real question behind them — this
decision buys the column that would carry either.

**Three slots may turn out to be two too few.** The 16:20 yogurt on the artboard is a
snack, and it lands in dinner. That is not obviously wrong — it is on the dinner side of
the day — but it is the first thing the dataset should be asked about after the 21 days,
and `alter type` is one line when it is.
