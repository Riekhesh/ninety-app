/**
 * The validation the app depends on, tested without a network or a key.
 *
 * `deno test supabase/functions` — it runs on Ubuntu in CI, alongside the RLS
 * proof and the vision harness self-test, because none of this needs a Mac.
 *
 * The cases here are the ones a structured output CANNOT prevent. Constraining
 * the response's shape is not constraining its sense: the schema has no numeric
 * constraints (they are unsupported), so an inverted range, a negative bound and
 * an unrecognised confidence level are all schema-valid and all wrong.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseEstimate, EstimateParseError } from "./schema.ts";
import { toGeminiSchema } from "./providers.ts";
import { ESTIMATE_SCHEMA } from "./schema.ts";

const item = {
  name: "porridge with milk",
  grams_low: 200,
  grams_high: 280,
  kcal_low: 290,
  kcal_high: 390,
  confidence: "high",
};

Deno.test("a well-formed response passes through unchanged", () => {
  const estimate = parseEstimate({ items: [item], notes: "" });
  assertEquals(estimate.items.length, 1);
  assertEquals(estimate.items[0].kcal_low, 290);
  assertEquals(estimate.warnings.length, 0);
});

Deno.test("an inverted range is swapped rather than rejected", () => {
  const estimate = parseEstimate({
    items: [{ ...item, kcal_low: 390, kcal_high: 290 }],
    notes: "",
  });
  assertEquals(estimate.items[0].kcal_low, 290);
  assertEquals(estimate.items[0].kcal_high, 390);
  assertEquals(estimate.warnings.length, 1);
});

Deno.test("a negative bound is clamped to zero", () => {
  const estimate = parseEstimate({ items: [{ ...item, kcal_low: -40 }], notes: "" });
  assertEquals(estimate.items[0].kcal_low, 0);
});

Deno.test("an unknown confidence level becomes medium", () => {
  const estimate = parseEstimate({ items: [{ ...item, confidence: "certain" }], notes: "" });
  assertEquals(estimate.items[0].confidence, "medium");
  assertEquals(estimate.warnings.length, 1);
});

Deno.test("one bad item does not lose the good ones", () => {
  const estimate = parseEstimate({
    items: [item, { ...item, name: "banana", kcal_low: "not a number" }],
    notes: "",
  });
  assertEquals(estimate.items.length, 1);
  assertEquals(estimate.items[0].name, "porridge with milk");
  assertEquals(estimate.warnings.length, 1);
});

Deno.test("a response with nothing usable in it is refused", () => {
  // There is nothing to confirm and nothing to correct, so the honest answer is
  // that the photo did not work — not an empty Under Review screen.
  assertThrows(() => parseEstimate({ items: [], notes: "" }), EstimateParseError);
  assertThrows(() => parseEstimate({ notes: "" }), EstimateParseError);
});

Deno.test("the Gemini schema loses additionalProperties and nothing else", () => {
  const adapted = toGeminiSchema(ESTIMATE_SCHEMA) as Record<string, unknown>;
  const json = JSON.stringify(adapted);

  // ADR 0010: Gemini rejects this key rather than ignoring it, so leaving it in
  // fails every call with a 400 that reads like a bad request.
  assertEquals(json.includes("additionalProperties"), false);

  // Everything that carries meaning survives.
  const properties = adapted.properties as Record<string, unknown>;
  const items = properties.items as Record<string, unknown>;
  const itemProperties = (items.items as Record<string, unknown>).properties as Record<
    string,
    unknown
  >;
  assertEquals(Object.keys(itemProperties).sort(), [
    "confidence",
    "grams_high",
    "grams_low",
    "kcal_high",
    "kcal_low",
    "name",
  ]);
  assertEquals((items.items as Record<string, unknown>).required !== undefined, true);
});
