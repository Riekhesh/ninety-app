# Supabase + PostHog — the sit-down-once runbook

**§0.2 wants these created now so they are not admin later.** Neither is needed to
write code today: Supabase matters from Phase 1, PostHog from Phase 3. Doing them
during the Apple enrolment wait is the whole point — it is the one stretch where the
critical path is blocked and this is not.

**Budget ~25 minutes for both.** When you finish, run:

```bash
scripts/verify-accounts.sh
```

That is the testable condition (§00 rule 2). A ticked checkbox is not.

> Both dashboards move their UI around. The **values** below are the decisions and they
> do not move; if a label has been renamed, the value still tells you what you are
> looking for.

---

## Before you start

```bash
cp .env.example .env          # if you have not already
git check-ignore -v .env      # must print a matching .gitignore rule
```

If that second command prints nothing, **stop** and fix it before pasting any key.
Everything below produces secrets, and `.env` is where they go — never the app bundle,
never a commit ([secrets.md](../security/secrets.md)).

---

## 1 · Supabase (~15 min)

[supabase.com/dashboard](https://supabase.com/dashboard) → sign in with GitHub → **New
project**.

| Setting | Value | Why this one |
|---|---|---|
| Organisation | new, free tier | — |
| Name | `notch` | matches the repo |
| **Region** | **London / `eu-west-2`** (any EU region if London is unavailable) | **The decision that is expensive to change.** This is special category health data under UK GDPR Article 9. Region is fixed at creation — moving it later means a dump, a new project, and reissuing every key. |
| Database password | generate a long random one | goes straight into `.env` as `SUPABASE_DB_PASSWORD`; you will need it for migrations, and it is not retrievable afterwards |
| Plan | Free | comfortably covers Phases 0–3 ([ADR 0003](../decisions/0003-supabase-backend.md)) |

Provisioning takes a couple of minutes. Then **Project Settings → API**, and copy four
values into `.env`:

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=...              # public by design — ships in the app bundle
SUPABASE_SERVICE_ROLE_KEY=...      # bypasses RLS entirely. Treat as a root password.
SUPABASE_DB_PASSWORD=...           # the one you generated above
```

**Then stop.** Do not create a table, and do not use the dashboard's table editor.

[ADR 0003](../decisions/0003-supabase-backend.md) and §1.1 both require RLS on every
table from the **first migration**, and the anon key above is public — so a table
without a policy is a public table holding health data. Phase 1 creates the schema as
migrations, with policies, tested with two real accounts. A table clicked into existence
now is a table nobody wrote a policy for.

The one thing worth doing while you are in there: **Authentication → Providers**, and
note that Apple is available. You will configure it in Phase 1, once the Apple
enrolment has cleared and you have a Services ID to configure it *with*. There is
nothing to do today.

---

## 2 · PostHog — **deferred to Phase 3** (decided 2026-08-30)

> **Not done, on purpose.** PostHog is not needed until there are real testers
> generating behaviour worth measuring, and it blocks nothing before then. §0.2's
> argument for doing it in Phase 0 was only that admin is cheaper when batched — which
> is a weak reason to sign up for a third service today. `verify-accounts.sh` treats a
> blank PostHog key as a note rather than a failure, so this does not sit in the output
> looking like an outstanding task.
>
> **What changes when you do come back to it:** the two toggles below are the whole
> point, and they have to be off *before* the first event, not after. Everything else
> here is ten minutes of clicking.

### The instructions, for when you get to Phase 3

[eu.posthog.com](https://eu.posthog.com) — **note the `eu.`**. Same Article 9 reasoning
as the Supabase region, and `.env.example` already points `POSTHOG_HOST` at
`https://eu.i.posthog.com`. Signing up on the US cloud puts UK health-app telemetry in
the wrong jurisdiction and, like the Supabase region, is not movable afterwards.

Create a project named `notch`. **Project Settings**, and copy:

```
POSTHOG_PROJECT_API_KEY=phc_...    # write-only ingest key; safe in the app bundle
POSTHOG_HOST=https://eu.i.posthog.com
```

### Turn three things off before you forget

This is the part that matters, and it is much easier now than after the first tester.

| Setting | Set to | Why |
|---|---|---|
| **Session replay** | **off** | It records the screen. On this app the screen is someone's weight, their food, and their tier. There is no version of that which belongs in an analytics tool. |
| **Autocapture** | **off** | It captures element text automatically, which on a food log means the food. §3.3 wants a named event when a user logs a meal, not the meal. |
| **Person profiles** | identified only | No profile for anonymous traffic; nothing accumulates against a device before there is a user to attach it to. |

§10's analytics position is a small number of deliberate events, each one added because
a specific question needs answering. Autocapture is the opposite instinct — collect
everything, decide later — and "decide later" is not a lawful basis.

---

## 3 · GitHub secret scanning (~2 min)

Repo **Settings → Code security** → enable **Secret scanning** *and* **Push
protection**.

Push protection blocks the push rather than emailing you afterwards, which is the
difference between a non-event and a rotation. It is the third tripwire in
[secrets.md](../security/secrets.md#tripwires); the other two are already in the repo.

---

## When you are done

```bash
scripts/verify-accounts.sh
```

It checks the keys are present, non-blank and the right shape, that the EU host is set,
and that `.env` is still ignored. It never prints a key value.

**What it cannot check, and you should confirm by eye:** the Supabase region is EU, and
session replay and autocapture are off in PostHog. Both are one-way doors of different
kinds — the region cannot be changed, and data collected before you turned replay off
was still collected.
