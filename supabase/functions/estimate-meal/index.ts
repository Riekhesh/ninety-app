/**
 * `estimate-meal` — the photo route's server half.
 *
 * The app uploads a downscaled JPEG to the private `meal-photos` bucket and
 * posts the path here. This claims the caller's daily quota, reads the object,
 * asks the vision provider with a schema constraining the response, sanity-checks
 * what comes back, and returns it. It never writes a `food_logs` row: nothing is
 * logged until the user gives the decision on Under Review (ADR 0010), and the
 * server having no way to log is what makes that structural rather than a habit.
 *
 * **The model key lives here and only here.** §04: a key in a client binary is
 * extractable in minutes, and `no_embedded_secrets` in `.swiftlint.yml` is the
 * tripwire on the app side. This function is the reason that rule can be an
 * error rather than a warning.
 *
 * ## Order of operations, and why it is this order
 *
 * 1. Identify the caller.
 * 2. Check the path belongs to them.
 * 3. Read the object.
 * 4. **Claim the quota.**
 * 5. Call the model.
 *
 * The claim sits between the read and the model call on purpose. Earlier, and a
 * malformed request burns a slot for nothing. Later, and two concurrent requests
 * both reach the model before either has counted. And it is deliberately **not
 * refunded** when the model call fails: the thing this cap exists to bound is a
 * client stuck in a retry loop, and a loop that always errors would be refunded
 * forever.
 *
 * Deploy and configuration: `supabase/functions/README.md`.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseEstimate, EstimateParseError } from "./schema.ts";
import { buildProvider, VisionRefusal, VisionUnavailable } from "./providers.ts";
import { PROMPT_VERSION, promptHash } from "./prompt.ts";

const BUCKET = "meal-photos";

/**
 * §10's abuse control. Thirty a day: generous enough that nobody logging real
 * meals reaches it, small enough that a runaway client costs pennies. At the
 * measured $0.000862 an image that is under 3p a day at the ceiling.
 */
const DEFAULT_DAILY_CAP = 30;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    console.error("estimate-meal: SUPABASE_URL / ANON / SERVICE_ROLE not all present");
    return json({ error: "misconfigured" }, 500);
  }

  // Two clients, and the split is the security boundary. The caller's client
  // answers "who is this" under their own RLS; the service client reads the
  // object and writes the quota ledger, which the caller is never allowed to do.
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const service = createClient(url, serviceKey);

  const { data: userData, error: userError } = await caller.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let storagePath: string;
  try {
    const body = await request.json();
    storagePath = String(body?.storage_path ?? "");
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  // The storage policies already compare the first path segment against
  // auth.uid(), but the service client below bypasses RLS entirely — so this
  // check is not defence in depth, it is THE check for the read that follows.
  // Without it, a signed-in user could name any other user's object and have
  // this function fetch it for them.
  if (!storagePath || !storagePath.startsWith(`${user.id}/`) || storagePath.includes("..")) {
    console.warn(`estimate-meal: rejected path for ${user.id}`);
    return json({ error: "forbidden" }, 403);
  }

  const { data: object, error: downloadError } = await service.storage
    .from(BUCKET)
    .download(storagePath);
  if (downloadError || !object) {
    return json({ error: "not_found" }, 404);
  }

  const cap = Number(Deno.env.get("NINETY_PHOTO_DAILY_CAP") ?? DEFAULT_DAILY_CAP);
  const { data: claimed, error: claimError } = await service.rpc("claim_photo_estimate", {
    p_user: user.id,
    p_cap: cap,
  });
  if (claimError) {
    console.error(`estimate-meal: claim failed — ${claimError.message}`);
    return json({ error: "unavailable" }, 503);
  }
  if (typeof claimed !== "number" || claimed < 0) {
    // Calm copy and an intact manual path is the app's job; this just says which
    // limit and what it is, so the client is never guessing.
    return json({ error: "daily_cap_reached", cap }, 429);
  }

  const bytes = new Uint8Array(await object.arrayBuffer());
  const mimeType = object.type || "image/jpeg";

  let provider;
  try {
    provider = buildProvider();
  } catch (error) {
    console.error(`estimate-meal: ${(error as Error).message}`);
    return json({ error: "unavailable" }, 503);
  }

  try {
    const result = await provider.estimate(base64(bytes), mimeType);
    const estimate = parseEstimate(result.raw);

    console.info(
      JSON.stringify({
        event: "estimate",
        provider: provider.name,
        model: result.model,
        prompt: `${PROMPT_VERSION}:${await promptHash()}`,
        latency_ms: result.latencyMs,
        input_tokens: result.inputTokens,
        output_tokens: result.outputTokens,
        items: estimate.items.length,
        // A model that needs frequent repair is telling you something, and this
        // is the only place it would ever be visible.
        warnings: estimate.warnings.length,
        used_today: claimed,
        cap,
      }),
    );

    return json({
      items: estimate.items,
      notes: estimate.notes,
      model: result.model,
      storage_path: storagePath,
    });
  } catch (error) {
    if (error instanceof EstimateParseError) {
      console.warn(`estimate-meal: unusable response — ${error.message}`);
      return json({ error: "unreadable" }, 422);
    }
    if (error instanceof VisionRefusal) {
      // Food photographs should never reach this. If one does, it is worth
      // seeing in the logs rather than being flattened into a 503.
      console.warn(`estimate-meal: refusal — ${error.message}`);
      return json({ error: "unreadable" }, 422);
    }
    if (error instanceof VisionUnavailable) {
      console.error(`estimate-meal: provider unavailable — ${error.message}`);
      return json({ error: "unavailable" }, 503);
    }
    console.error(`estimate-meal: ${(error as Error).message}`);
    return json({ error: "unavailable" }, 503);
  }
});

/**
 * Bytes to base64, in chunks.
 *
 * `String.fromCharCode(...bytes)` on a whole image is a spread of ~700,000
 * arguments and blows the call stack — it works on the small test image and
 * fails on a real photograph, which is the worst possible place for that
 * boundary to be.
 */
function base64(bytes: Uint8Array): string {
  const chunk = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}
