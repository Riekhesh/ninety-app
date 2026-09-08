/**
 * Vision providers behind one interface (ADR 0010).
 *
 * A port of `spikes/vision-accuracy/ninetyvision/providers.py` to raw HTTP.
 * Deno rather than the Python SDKs, and raw `fetch` rather than the JS ones: the
 * function needs one request per provider and nothing else, and three SDK
 * imports in an Edge Function is three cold-start costs paid on every meal.
 *
 * **Gemini is the default** (ADR 0010, amended twice): the developer holds
 * Gemini credit and none with Anthropic, and images are almost entirely INPUT
 * tokens where `gemini-3.5-flash-lite` is 5x cheaper than the newer flash. The
 * interface is the decision that matters and it is unchanged — swapping arms is
 * one environment variable.
 *
 * The API details below are not from memory. Each is the shape the spike's
 * Python already calls successfully, translated:
 *
 * · **Anthropic.** `temperature` is REJECTED with a 400 on `claude-opus-5`, not
 *   ignored — do not add one. `effort` and `format` both live inside
 *   `output_config`, not at the top level. Thinking blocks precede the text
 *   block, so the JSON is found by scanning `content` for `type === "text"`
 *   rather than by indexing `content[0]`.
 * · **Gemini.** `responseSchema` is an OpenAPI 3.0 subset, not full JSON Schema:
 *   `additionalProperties` is rejected rather than ignored, so the shared schema
 *   is adapted by `toGeminiSchema`. Losing it means Gemini may return keys we
 *   did not ask for; `parseEstimate` ignores unknown keys.
 * · **OpenAI.** `response_format.json_schema` with `strict: true`.
 */

import { ESTIMATE_SCHEMA } from "./schema.ts";
import { SYSTEM_PROMPT, USER_PROMPT } from "./prompt.ts";

export interface ProviderResult {
  /** The model's JSON, parsed but not yet sanity-checked. */
  raw: Record<string, unknown>;
  model: string;
  latencyMs: number;
  inputTokens: number;
  outputTokens: number;
}

export interface VisionProvider {
  readonly name: string;
  readonly model: string;
  estimate(imageBase64: string, mimeType: string): Promise<ProviderResult>;
}

export class VisionRefusal extends Error {}
export class VisionUnavailable extends Error {}

const DEFAULT_MODELS: Record<string, string> = {
  gemini: "gemini-3.5-flash-lite",
  anthropic: "claude-opus-5",
  openai: "gpt-5",
};

const MAX_TOKENS = 2000;

/**
 * Which provider this deployment uses.
 *
 * Model ids move faster than this file does — ADR 0010 records a Gemini id
 * being retired for new keys mid-benchmark and returning a 404 that read like a
 * harness bug. So the id is an environment variable with a default, not a
 * constant, and a "model not found" is fixed by a `secrets set` rather than a
 * deploy.
 */
export function buildProvider(): VisionProvider {
  const name = (Deno.env.get("NINETY_VISION_PROVIDER") ?? "gemini").toLowerCase();
  const model = Deno.env.get("NINETY_VISION_MODEL") || DEFAULT_MODELS[name];
  if (!model) throw new VisionUnavailable(`unknown provider '${name}'`);

  switch (name) {
    case "gemini":
      return new GeminiProvider(model);
    case "anthropic":
      return new AnthropicProvider(model);
    case "openai":
      return new OpenAIProvider(model);
    default:
      throw new VisionUnavailable(`unknown provider '${name}'`);
  }
}

function requireKey(names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value) return value;
  }
  // Named rather than generic: this is the single most likely deployment
  // mistake, and "the estimator isn't answering" in the app should have a log
  // line that says exactly which secret is missing.
  throw new VisionUnavailable(`none of ${names.join(", ")} is set on this function`);
}

async function postJSON(url: string, headers: HeadersInit, body: unknown): Promise<Response> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new VisionUnavailable(`${response.status}: ${detail.slice(0, 400)}`);
  }
  return response;
}

// ─── Gemini ─────────────────────────────────────────────────────────────────

/** Keys Gemini's responseSchema rejects rather than ignores. */
const GEMINI_UNSUPPORTED = new Set(["additionalProperties", "$schema", "default", "examples"]);

export function toGeminiSchema(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(toGeminiSchema);
  if (!schema || typeof schema !== "object") return schema;

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(schema as Record<string, unknown>)) {
    if (GEMINI_UNSUPPORTED.has(key)) continue;
    if (key === "properties" && value && typeof value === "object") {
      const properties = value as Record<string, unknown>;
      out.properties = Object.fromEntries(
        Object.entries(properties).map(([k, v]) => [k, toGeminiSchema(v)]),
      );
      // Stable field order, so a raw response is readable by eye.
      out.propertyOrdering = Object.keys(properties);
    } else if (key === "items") {
      out.items = toGeminiSchema(value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

class GeminiProvider implements VisionProvider {
  readonly name = "gemini";
  constructor(readonly model: string) {}

  async estimate(imageBase64: string, mimeType: string): Promise<ProviderResult> {
    const key = requireKey(["GEMINI_API_KEY", "GOOGLE_API_KEY"]);
    const started = performance.now();

    const response = await postJSON(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`,
      { "x-goog-api-key": key },
      {
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [
          {
            role: "user",
            parts: [
              { inline_data: { mime_type: mimeType, data: imageBase64 } },
              { text: USER_PROMPT },
            ],
          },
        ],
        generationConfig: {
          maxOutputTokens: MAX_TOKENS,
          responseMimeType: "application/json",
          responseSchema: toGeminiSchema(ESTIMATE_SCHEMA),
        },
      },
    );

    const body = await response.json();
    const text: string | undefined = body?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      // Gemini signals a content-policy block through promptFeedback and returns
      // no text at all, rather than through a stop reason.
      throw new VisionRefusal(
        `no text returned (promptFeedback=${JSON.stringify(body?.promptFeedback ?? null)})`,
      );
    }

    const usage = body?.usageMetadata ?? {};
    return {
      raw: JSON.parse(text),
      model: this.model,
      latencyMs: Math.round(performance.now() - started),
      inputTokens: usage.promptTokenCount ?? 0,
      outputTokens: usage.candidatesTokenCount ?? 0,
    };
  }
}

// ─── Anthropic ──────────────────────────────────────────────────────────────

class AnthropicProvider implements VisionProvider {
  readonly name = "anthropic";
  constructor(readonly model: string) {}

  async estimate(imageBase64: string, mimeType: string): Promise<ProviderResult> {
    const key = requireKey(["ANTHROPIC_API_KEY"]);
    const started = performance.now();

    const response = await postJSON(
      "https://api.anthropic.com/v1/messages",
      { "x-api-key": key, "anthropic-version": "2023-06-01" },
      {
        model: this.model,
        max_tokens: MAX_TOKENS,
        // Cached: the system prompt is comfortably over the minimum, so a busy
        // hour pays one write and many reads at ~0.1x.
        system: [
          { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
        ],
        output_config: {
          format: { type: "json_schema", schema: ESTIMATE_SCHEMA },
        },
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: mimeType, data: imageBase64 },
              },
              { type: "text", text: USER_PROMPT },
            ],
          },
        ],
        // NO temperature - rejected with a 400 on this model.
      },
    );

    const body = await response.json();
    if (body?.stop_reason === "refusal") {
      throw new VisionRefusal("declined by the model's classifiers; content is empty or partial");
    }

    // Thinking blocks come first on this model. Find the text block by type
    // rather than indexing content[0], which returns an empty thinking block.
    const text: string | undefined = (body?.content ?? []).find(
      (block: { type?: string }) => block?.type === "text",
    )?.text;
    if (!text) {
      throw new VisionUnavailable(`no text block (stop_reason=${body?.stop_reason})`);
    }

    const usage = body?.usage ?? {};
    return {
      raw: JSON.parse(text),
      model: this.model,
      latencyMs: Math.round(performance.now() - started),
      inputTokens: (usage.input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0),
      outputTokens: usage.output_tokens ?? 0,
    };
  }
}

// ─── OpenAI (comparison arm) ────────────────────────────────────────────────

class OpenAIProvider implements VisionProvider {
  readonly name = "openai";
  constructor(readonly model: string) {}

  async estimate(imageBase64: string, mimeType: string): Promise<ProviderResult> {
    const key = requireKey(["OPENAI_API_KEY"]);
    const started = performance.now();

    const response = await postJSON(
      "https://api.openai.com/v1/chat/completions",
      { authorization: `Bearer ${key}` },
      {
        model: this.model,
        max_completion_tokens: MAX_TOKENS,
        response_format: {
          type: "json_schema",
          json_schema: { name: "meal_estimate", strict: true, schema: ESTIMATE_SCHEMA },
        },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: USER_PROMPT },
              {
                type: "image_url",
                image_url: { url: `data:${mimeType};base64,${imageBase64}` },
              },
            ],
          },
        ],
      },
    );

    const body = await response.json();
    const text: string | undefined = body?.choices?.[0]?.message?.content;
    if (!text) throw new VisionUnavailable("no content in response");

    const usage = body?.usage ?? {};
    return {
      raw: JSON.parse(text),
      model: this.model,
      latencyMs: Math.round(performance.now() - started),
      inputTokens: usage.prompt_tokens ?? 0,
      outputTokens: usage.completion_tokens ?? 0,
    };
  }
}
