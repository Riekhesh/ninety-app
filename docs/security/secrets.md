# Secrets handling

**Status:** decided in Phase 0. This is a Phase 0 exit criterion ("secrets handling
decided").

---

## The one rule

> **No secret ever enters the app bundle or this repository.**

A key compiled into an iOS binary is not hidden. `strings` on an extracted `.ipa`
finds it in seconds, and TestFlight builds are trivially extractable. The brief
puts this plainly in §04: *"Never call the AI API from the app. Keys embedded in a
client binary are extractable in minutes."*

This is not a theoretical concern. Anthropic and OpenAI keys leaked from mobile
apps get scraped and used, and the bill is yours.

---

## Where each secret actually lives

| Secret | Lives in | Reachable from the app? |
|---|---|---|
| Anthropic / OpenAI API key | Supabase Edge Function env var | **No.** The app calls the Edge Function; the function calls the model. |
| Supabase **secret** key (`sb_secret_…`, formerly `service_role`) | Supabase Edge Function env var, and your local `.env` for migrations | **No.** It bypasses Row-Level Security — treat it like a root password. |
| Supabase **publishable** key (`sb_publishable_…`, formerly `anon`) | App bundle, and it is *designed* to be there | Yes. Safe by design: it only grants what RLS policies allow. **This makes RLS the actual security boundary — see below.** |
| Supabase project URL | App bundle | Yes. Not a secret. |
| Apple signing certs, `.p8` App Store Connect key | macOS Keychain, and Xcode-managed | No |
| PostHog project API key | App bundle | Yes. Write-only ingest key; safe by design. |

### The publishable key consequence worth internalising

> **Naming.** Supabase renamed these to *publishable* and *secret*; the roles are
> unchanged, and everything below applies identically. Prefer them over the legacy
> tab — a legacy key can only be rotated by rotating the project JWT secret, which
> invalidates every key and signs out every user at once, whereas the new ones revoke
> one at a time. Rotation being cheap is what makes the rule below workable.

The publishable key being public means **Row-Level Security is not a defence-in-depth
nicety — it is the only thing standing between one user and everybody's health
data.** Anyone can extract the anon key and hit your Postgres directly with it.

This is why §1.1 insists RLS goes on every table in the first migration rather
than being retrofitted. A table without an RLS policy, reachable with the anon
key, is a public table.

Phase 1 exit criteria include "RLS policies on every table, tested with two
accounts". Test it by actually signing in as user B and trying to read user A's
`food_logs`. Assume it is broken until you have seen it fail.

---

## Local development

Secrets for local tooling go in `.env`, which is gitignored. `.env.example` is
committed and lists the *names* only.

```bash
cp .env.example .env
# fill it in, then verify it is invisible to git:
git check-ignore -v .env    # must print a matching .gitignore rule
```

The vision-accuracy spike reads `ANTHROPIC_API_KEY` from the environment and
never writes it to disk, to its cache, or to its run logs. Its report output
records the *model id and prompt hash* so a baseline is reproducible, but never
the key.

---

## Edge Function secrets

```bash
# set (never echoed back, never in shell history if you use a leading space)
 supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# list names only — values are not retrievable, which is correct
supabase secrets list
```

If you ever need to see a value, you cannot, and that is the design. Rotate
instead.

---

## Rotation

Rotate immediately if a key is pasted into a chat, a screenshot, an issue, a
commit — or if you are merely unsure. Rotation is five minutes; a compromised
key is not.

**A secret that reached a commit is compromised even after you delete it.**
`git rm` does not remove it from history, and force-pushing a rewritten history
does not remove it from any clone, fork, or GitHub's own cached views. Rotate
first, then clean history if you want to, in that order.

---

## Tripwires

Three layers, cheapest first:

1. **`.gitignore`** — covers `.env`, `*.p8`, `*.p12`, `*.pem`, `Secrets.swift`,
   `Secrets.xcconfig`, `supabase/.env`.
2. **SwiftLint `no_embedded_secrets`** (in `.swiftlint.yml`, severity `error`) —
   fails the build on `sk-ant-`, `sk-proj-`, and `apiKey = "..."` patterns in
   Swift source.
3. **GitHub secret scanning** — on for private repos with push protection.
   Enable it in the repo settings; it blocks the push rather than telling you
   afterwards.

None of the three catches everything. The habit is the control; these are the
safety net.

---

## Before the first external tester (Phase 3)

- [ ] Per-user daily cap on vision calls, enforced **in the Edge Function**, not
      the client (§10 — "add the cap before you hand the app to anyone, not
      after a surprise bill")
- [ ] Edge Function verifies the caller's JWT — an unauthenticated function that
      proxies a paid model API is an open relay
- [ ] Supabase Storage bucket for meal photos is private with an RLS policy;
      signed URLs only, short expiry
- [ ] GitHub secret scanning with push protection enabled
