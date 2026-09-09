/**
 * The structured-output contract, and the only place it is written down for the
 * server.
 *
 * It is a port of `spikes/vision-accuracy/ninetyvision/schema.py`, deliberately
 * field for field. §1.3 called that schema "the contract the Phase 1 Edge
 * Function will honour", and the value of having built it in the spike is that
 * a run over 20 weighed meals scores exactly the shape this returns.
 *
 * Two properties carry the whole design:
 *
 * · **Ranges, not points.** A single number is a lie the UI then has to render.
 *   Trained dietitians misestimate portions by 20-30% and models do worse.
 * · **Confidence per item, not per photo.** A plate can hold one obvious thing
 *   and one ambiguous thing, and the correction screen needs to know which.
 *
 * Structured outputs constrain the response's SHAPE. They cannot constrain its
 * SENSE — numeric constraints (`minimum`, `maximum`) are not supported — so
 * `low > high` and negatives are repaired in `parseEstimate` below, and again
 * on the client in `MealEstimatePayload.validated`. Both, because they are
 * different trust boundaries: this one protects the response, that one protects
 * the app from this.
 */

export const CONFIDENCE_LEVELS = ["low", "medium", "high"] as const;
export type Confidence = (typeof CONFIDENCE_LEVELS)[number];

export const ESTIMATE_SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      description:
        "One entry per distinct food visible. Split composite dishes only when the components are separately identifiable.",
      items: {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "Short common name, e.g. 'porridge with milk'.",
          },
          grams_low: {
            type: "integer",
            description: "Low end of the plausible portion weight in grams.",
          },
          grams_high: {
            type: "integer",
            description: "High end of the plausible portion weight in grams.",
          },
          kcal_low: {
            type: "integer",
            description: "Low end of plausible energy, consistent with grams_low.",
          },
          kcal_high: {
            type: "integer",
            description: "High end of plausible energy, consistent with grams_high.",
          },
          confidence: {
            type: "string",
            enum: [...CONFIDENCE_LEVELS],
            description:
              "high: clearly identifiable and portion judgeable against a reference. medium: identifiable, portion uncertain. low: identity or preparation genuinely ambiguous.",
          },
        },
        required: ["name", "grams_low", "grams_high", "kcal_low", "kcal_high", "confidence"],
        additionalProperties: false,
      },
    },
    notes: {
      type: "string",
      description:
        "What could not be determined from the photo — hidden oil, unseen sugar, obscured portions. Empty string if nothing to flag.",
    },
  },
  required: ["items", "notes"],
  additionalProperties: false,
} as const;

export interface EstimatedItem {
  name: string;
  grams_low: number;
  grams_high: number;
  kcal_low: number;
  kcal_high: number;
  confidence: Confidence;
}

export interface Estimate {
  items: EstimatedItem[];
  notes: string;
  /** What had to be repaired. Returned so a model that needs frequent repair is visible. */
  warnings: string[];
}

export class EstimateParseError extends Error {}

/**
 * Parse and sanity-check a model response.
 *
 * Repairs rather than rejects, exactly as the spike's `parse_estimate` does:
 * throwing away four good items because of one inverted range is a worse
 * outcome than a swapped pair and a recorded warning.
 */
export function parseEstimate(raw: string | Record<string, unknown>): Estimate {
  const data = typeof raw === "string" ? JSON.parse(raw) : raw;
  if (!data || typeof data !== "object" || !Array.isArray((data as { items?: unknown }).items)) {
    throw new EstimateParseError("no 'items' array in response");
  }

  const items: EstimatedItem[] = [];
  const warnings: string[] = [];

  (data as { items: unknown[] }).items.forEach((entry, index) => {
    if (!entry || typeof entry !== "object") {
      warnings.push(`item ${index}: not an object, dropped`);
      return;
    }
    const raw = entry as Record<string, unknown>;

    let name = String(raw.name ?? "").trim();
    let gLo = Number(raw.grams_low);
    let gHi = Number(raw.grams_high);
    let kLo = Number(raw.kcal_low);
    let kHi = Number(raw.kcal_high);
    let confidence = String(raw.confidence ?? "").toLowerCase();

    if ([gLo, gHi, kLo, kHi].some((n) => !Number.isFinite(n))) {
      warnings.push(`item ${index} (${name || "unnamed"}): non-numeric bound, dropped`);
      return;
    }
    if (!name) {
      warnings.push(`item ${index}: empty name`);
      name = "unnamed";
    }
    if (gLo > gHi) {
      warnings.push(`item ${index} (${name}): grams range inverted, swapped`);
      [gLo, gHi] = [gHi, gLo];
    }
    if (kLo > kHi) {
      warnings.push(`item ${index} (${name}): kcal range inverted, swapped`);
      [kLo, kHi] = [kHi, kLo];
    }
    if (gLo < 0 || kLo < 0) {
      warnings.push(`item ${index} (${name}): negative bound clamped to 0`);
      gLo = Math.max(0, gLo);
      kLo = Math.max(0, kLo);
    }
    if (!(CONFIDENCE_LEVELS as readonly string[]).includes(confidence)) {
      warnings.push(`item ${index} (${name}): unknown confidence '${confidence}' -> medium`);
      confidence = "medium";
    }

    items.push({
      name,
      grams_low: gLo,
      grams_high: gHi,
      kcal_low: kLo,
      kcal_high: kHi,
      confidence: confidence as Confidence,
    });
  });

  if (items.length === 0) {
    // Nothing to confirm and nothing to correct. The client degrades to manual
    // entry rather than drawing an empty Under Review screen.
    throw new EstimateParseError("no usable items in response");
  }

  return { items, notes: String((data as { notes?: unknown }).notes ?? ""), warnings };
}
