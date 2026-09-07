# Supabase

Postgres, auth, storage (ADR 0003). **RLS is not defence-in-depth here — it is
the security boundary.** The publishable key ships in the app bundle and is
public by design, so a table without a policy is a public table, and by week
three this database holds real health data that is special category under UK
GDPR Article 9.

```
migrations/   applied in filename order by `supabase db push`
tests/        the local harness. NEVER applied to a project
```

## Verify

```bash
scripts/verify-rls.sh
```

Boots a throwaway Postgres, applies the migrations exactly as `db push` would,
and runs the two-account proof — 27 assertions covering read, update, delete,
forgery and reassignment across all ten tables plus the storage bucket. Runs in
CI on every PR that touches this directory.

## Applying this to your Supabase project

Once, from the repo root on your Mac. Stop at the first step that fails.

### 1. Install the CLI

```bash
brew install supabase/tap/supabase
supabase --version
```

### 2. Sign in

```bash
supabase login
```

Opens a browser, asks you to authorise, and writes a token to your machine.
Nothing repo-related happens here.

### 3. Find your project ref

It is the subdomain of your project URL — `https://<ref>.supabase.co` — and is
also shown in the dashboard under **Settings → General → Reference ID**. Twenty
lowercase letters. If you have `SUPABASE_URL` in your `.env`, it is in there.

### 4. Link this repo to that project

```bash
supabase link --project-ref <your-ref>
```

It asks for your **database password** — the one set when the project was
created, not your account password. If you do not have it: dashboard →
**Settings → Database → Reset database password**. Resetting it is safe at this
stage; nothing is connected yet.

This writes to `supabase/.temp/`, which is gitignored.

### 5. See what it is about to do — before it does it

```bash
supabase migration list
```

Prints a table of local vs remote migrations. Expect three rows with a local
timestamp and no remote one. **If any remote migration is listed that you do not
recognise, stop** — this project has been migrated by something else, and
pushing on top of it needs a look first.

### 6. Push

```bash
supabase db push
```

It lists the migrations and asks to confirm. Three should apply in order.

### 7. Check it landed

```bash
supabase migration list
```

Every row should now show both a local and a remote timestamp.

Then, in the dashboard, **Database → Tables**: ten tables, each with a
green **RLS enabled** badge. **Authentication → Policies** should show four
policies on most tables, one on `leaderboard_entries`.

---

### If Homebrew will not install the CLI

`Error: Your Command Line Tools are too outdated.` is Homebrew checking the
standalone Command Line Tools package, which is versioned separately from
Xcode. Having Xcode 26.6 does not update it.

**Fix it properly** (worth doing — it will block other `brew install`s too):

```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

~1 GB and several minutes. While it downloads, point the toolchain at Xcode so
nothing else breaks in the meantime:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then `brew install supabase/tap/supabase` and carry on from step 2.

**Or skip the CLI entirely** — see below. The CLI is only needed to apply
migrations and to keep the migration history in step; nothing in the app uses
it.

---

## Applying the migrations without the CLI

The dashboard's SQL Editor runs as `postgres`, so it can do everything `db
push` does. It just does not record what it ran, which the last step fixes.

1. Dashboard → **SQL Editor** → **New query**.
2. Paste the entire contents of `supabase/migrations/20260902000001_initial_schema.sql`
   and press **Run**. Expect `Success. No rows returned`.
3. Repeat for `..._20260902000002_rls_policies.sql`.
4. Repeat for `..._20260902000003_storage_meal_photos.sql`. If this one errors on
   permissions, see the section below — it is the expected one to fail and
   nothing needs it until P1-F.
5. Check: **Database → Tables** shows ten tables, each with a green
   **RLS enabled** badge.

**Then tell the CLI they are already applied**, so that when you do install it,
the next `db push` does not try to run them again and fail on
`type "food_source" already exists`:

```bash
supabase migration repair --status applied 20260902000001
supabase migration repair --status applied 20260902000002
supabase migration repair --status applied 20260902000003   # only if step 4 worked
```

Do this whenever you get round to installing the CLI. Until then the database
is correct and the app is unblocked; only the bookkeeping is outstanding.

### If step 6 fails on `20260902000003_storage_meal_photos.sql`

That one is separated from the others precisely because it is the step that can
fail for a reason that is not your SQL: `storage.objects` is owned by
`supabase_storage_admin`, not by the role running the migration, so on some
projects a migration cannot create policies on it.

**It is not urgent.** Nothing uses the photo bucket until P1-F. Migrations 001
and 002 will already have applied, and your tables are protected.

To do it by hand instead: dashboard → **Storage → New bucket**, name
`meal-photos`, leave **Public** OFF. Then **Policies → New policy** four times,
for SELECT / INSERT / UPDATE / DELETE, each with the expression:

```sql
bucket_id = 'meal-photos' and (storage.foldername(name))[1] = auth.uid()::text
```

### If you want to undo the whole thing

This is a fresh project with no data, so the blunt option is fine: dashboard →
**Settings → General → Delete project**, and create a new one. There is no
partial rollback worth building at this stage.

### What does NOT get pushed

`supabase/tests/` — including the `auth` and `storage` stubs. `db push` reads
`migrations/` only. That is why the stubs live where they do: they cannot reach
your project even by accident.

## The migrations

| | |
|---|---|
| `..._initial_schema.sql` | Ten tables, enums, indexes, triggers, and `enable row level security` on every one. RLS on with no policy denies everything, which is the safe direction to fail. |
| `..._rls_policies.sql` | Who may see what. Grants, per-table policies, the meal-photos bucket and its policies. |

Eight tables are live in Phase 1. `friendships` and `leaderboard_entries` ship
empty — nothing writes to them until Phase 4, and retrofitting relationships
into a live database holding real user data is the expensive version.

## Why the stubs exist

Supabase provides `auth.users`, `auth.uid()`, `storage.objects` and the
`anon` / `authenticated` roles. Vanilla Postgres does not, so without them the
migrations cannot be applied locally and the RLS cannot be tested at all.
`tests/00_local_supabase_stubs.sql` is the smallest set that makes the real
migrations run unmodified. The migrations are what ships; the stubs never leave
this machine.

## Not here yet

The Open Food Facts + USDA import. `foods` has its `search_vector` column and
GIN index, but the mirror itself is deferred — nothing in the minimum
daily-usable app needs it, and the 21-day clock is the one thing in Phase 1 no
effort compresses. It lands alongside P1-F's search route.
