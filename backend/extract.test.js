import { test } from "node:test";
import assert from "node:assert/strict";
import { createExtractor, sanitize, RESPONSE_SCHEMA, FIELDS, ExtractionError } from "./extract.js";

function fakeClient(response, capture = {}) {
  return {
    beta: {
      messages: {
        create: async (params) => {
          capture.params = params;
          return response;
        },
      },
    },
  };
}

const goodOutput = {
  medications: [
    {
      drug_name: { value: " Atorvastatin ", confidence: 0.95 },
      strength: { value: "20 mg", confidence: 1.7 },
      form: { value: "", confidence: 0.9 },
      dose: { value: "1 tablet", confidence: 0.9 },
      frequency: { value: "once daily", confidence: 0.8 },
      prescriber: { value: null, confidence: 0.5 },
      purpose: { value: null, confidence: 0 },
      extra: { value: "ignored", confidence: 1 },
    },
    Object.fromEntries(FIELDS.map((f) => [f, { value: null, confidence: 0 }])),
  ],
};

test("sanitize keeps known fields, trims, clamps, drops empty medications", () => {
  const out = sanitize(goodOutput);
  assert.equal(out.medications.length, 1);
  const med = out.medications[0];
  assert.deepEqual(Object.keys(med), FIELDS);
  assert.deepEqual(med.drug_name, { value: "Atorvastatin", confidence: 0.95 });
  assert.equal(med.strength.confidence, 1);
  assert.deepEqual(med.form, { value: null, confidence: 0 });
  assert.deepEqual(med.prescriber, { value: null, confidence: 0 });
  assert.deepEqual(sanitize(null), { medications: [] });
});

test("request uses structured output, fallbacks, and wraps OCR text as data", async () => {
  const capture = {};
  const extract = createExtractor({
    client: fakeClient({ stop_reason: "end_turn", content: [{ type: "text", text: JSON.stringify(goodOutput) }] }, capture),
    model: "claude-opus-5-5",
  });
  const out = await extract("ATORVASTATIN 20 MG", "nl");
  assert.equal(out.medications[0].drug_name.value, "Atorvastatin");
  const p = capture.params;
  assert.equal(p.model, "claude-opus-5-5");
  assert.equal(p.fallbacks, "default");
  assert.deepEqual(p.betas, ["server-side-fallback-2026-07-01"]);
  assert.deepEqual(p.output_config.format, { type: "json_schema", schema: RESPONSE_SCHEMA });
  assert.match(p.messages[0].content, /<ocr_text>\nATORVASTATIN 20 MG\n<\/ocr_text>/);
  assert.match(p.messages[0].content, /Dutch/);
});

test("refusal, truncation, garbage and empty input map to errors", async () => {
  const cases = [
    [{ stop_reason: "refusal", content: [] }, "refused"],
    [{ stop_reason: "max_tokens", content: [] }, "truncated"],
    [{ stop_reason: "end_turn", content: [{ type: "text", text: "not json" }] }, "invalid_model_output"],
  ];
  for (const [response, code] of cases) {
    const extract = createExtractor({ client: fakeClient(response) });
    await assert.rejects(extract("x"), (e) => e instanceof ExtractionError && e.code === code);
  }
  const extract = createExtractor({ client: fakeClient({}) });
  await assert.rejects(extract("   "), (e) => e.code === "empty_input");
});

test("schema requires every field so missing values come back as explicit nulls", () => {
  const item = RESPONSE_SCHEMA.properties.medications.items;
  assert.deepEqual(item.required, FIELDS);
  assert.equal(item.additionalProperties, false);
});
