# Edge Functions

One function, `estimate-meal`, and it exists for a single reason: **the model API
key must never be in the app bundle.** §04 is blunt about it — a key in a client
binary is extractable in minutes — and `no_embedded_secrets` in `.swiftlint.yml`
fails the build if one appears in Swift. This function is what makes that rule
possible to hold rather than merely stated.

```
estimate-meal/
  index.ts        the request: identify, authorise, claim, read, ask, validate
  providers.ts    Gemini · Anthropic · OpenAI behind one interface (ADR 0010)
  prompt.ts       the prompt, versioned and hashed
  schema.ts       the structured-output contract, and the repairs it needs
  schema_test.ts  deno test — no key, no network
```

## What it does, in order

1. **Identify the caller** from their JWT. `verify_jwt = true` in
   `supabase/config.toml`, so the token is verified before the function runs.
2. **Check the storage path belongs to them.** The path is `<user-id>/<file>`
   and the first segment has to match. This is not defence in depth — the read
   below uses the service role and bypasses RLS, so it is *the* check.
3. **Read the object** from the private `meal-photos` bucket.
4. **Claim the daily quota**, atomically, via `claim_photo_estimate`.
5. **Call the provider** with a JSON Schema constraining the response, then
   sanity-check what comes back.

It never writes a `food_logs` row. Nothing is logged until the user gives the
decision on Under Review (ADR 0010), and a server with no way to log is what
makes that structural.

## The daily cap

Thirty requests per user per UTC day, `NINETY_PHOTO_DAILY_CAP` to change it.

§10 asks for this *"before you hand the app to anyone, not after a surprise
bill."* At the measured $0.000862 an image it is an **abuse control rather than
a cost control** — the ceiling is under 3p a day — and what it actually bounds is
a client stuck in a retry loop.

Two details in `20260908000005_photo_estimate_usage.sql` worth knowing:

- **It counts requests, not confirmations.** Counting `photo_estimates` rows
  would miss every abandoned estimate, which is exactly the set the cap exists
  for.
- **The claim is one statement.** `insert … on conflict do update … where` is an
  atomic test-and-increment; read-then-write is a race that two concurrent
  requests both win, and concurrency is the failure mode being bounded.

A refused claim returns **429**, which the app turns into calm copy and an intact
manual path. The claim is deliberately **not refunded** when the model call
fails: a loop that always errors would be refunded forever.

## Deploying

From the repo root, with the CLI linked (`supabase/README.md` has the link
steps).

```bash
# The provider key. ONE of these, matching NINETY_VISION_PROVIDER.
supabase secrets set GEMINI_API_KEY=...

# Optional — the defaults are gemini / gemini-3.5-flash-lite (ADR 0010).
supabase secrets set NINETY_VISION_PROVIDER=gemini
supabase secrets set NINETY_VISION_MODEL=gemini-3.5-flash-lite
supabase secrets set NINETY_PHOTO_DAILY_CAP=30

supabase functions deploy estimate-meal
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
by the platform; do not set them yourself.

**Model ids move faster than this code does.** ADR 0010 records a Gemini id being
retired for new API keys mid-benchmark, returning a 404 that read like a harness
bug. That is why the id is a secret with a default rather than a constant: a
"model not found" is fixed with `secrets set`, not a deploy.

## Testing

```bash
deno test supabase/functions          # no key, no network, no cost
```

CI runs this on Ubuntu alongside the RLS proof. It covers the cases a structured
output cannot prevent — the schema has no numeric constraints, so an inverted
range, a negative bound and an unrecognised confidence level are all
schema-valid and all wrong.

## What is NOT here

**The estimate is never trusted on either side of the wire.** `schema.ts` repairs
the response here, and `MealEstimatePayload.validated` validates it again in the
app. That is not belt and braces — they are different trust boundaries. The first
protects the response from the model; the second protects the app from this
function, which is a separate deployable that can be older than the app talking
to it.
