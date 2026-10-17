# MedList extraction proxy (reference)

A small Node server that takes OCR text from the app and returns structured medication fields with per-field confidence. It calls the Claude API with structured outputs. **The API key lives only here.** The app never contains it.

```
POST /extract
X-MedList-Client: <token>            (only if MEDLIST_CLIENT_TOKEN is set)
{"text": "<OCR text, already redacted on device>", "language": "nl" | "en"}

200 {"medications": [{"drug_name": {"value": "Omeprazol", "confidence": 0.97}, "strength": {...}, ...}]}
4xx/5xx {"error": "rate_limited" | "refused" | "upstream_error" | ...}
```

The response shape matches `ExtractionResponse` in `MedListCore`. Any error makes the app fall back to the on-device parser and tell the user.

## Run

```bash
cd backend
npm install
ANTHROPIC_API_KEY=sk-ant-... MEDLIST_CLIENT_TOKEN=some-long-random-string npm start   # :8787
npm test                                                                              # no network, no key needed
```

| Env var | Default | |
|---|---|---|
| `ANTHROPIC_API_KEY` | (required) | Server-side only. |
| `MEDLIST_MODEL` | `claude-opus-5-5` | Use the eval to compare models (e.g. `claude-haiku-5-5`) on cost and accuracy before you change this. |
| `MEDLIST_EFFORT` | `low` | Extraction is transcription; raise it only if the eval shows a gain. |
| `MEDLIST_CLIENT_TOKEN` | (empty = no check) | Coarse gate only. It can be extracted from the app binary. |
| `MEDLIST_RATE_LIMIT` | `20` | Requests per IP per minute, in memory per instance. |
| `PORT` | `8787` | |

Then set `AppConfig.extractionEndpoint` (and `extractionClientToken`) in `MedList/App/AppEnvironment.swift`, rebuild, and turn on **Settings → Online label reading**.

## Design notes

- **Structured outputs** (`output_config.format` with a JSON schema) guarantee parseable JSON with every field present. `sanitize()` still clamps confidences, trims values and drops unknown keys.
- **Prompt-injection posture:** OCR text is wrapped in `<ocr_text>` and the system prompt says it is data. The worst a malicious label can do is produce wrong field values, and the caregiver confirms every field anyway.
- **Refusals:** `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`) retries a policy decline on the API's default substitute model. A final refusal returns `422 refused`.
- **No logging of content:** only method, path, status and duration are logged. Nothing is stored.
- `@anthropic-ai/sdk` is the only dependency, used for typed errors and beta parameters.

## Before production (see ../TODO.md)

- Sign a DPA with Anthropic and request **zero data retention** for this org. Health data is special-category data under GDPR. Confirm that the model you pick is available under ZDR.
- Host in the EU, use TLS only, and don't keep request logs at the load balancer.
- Replace the static client token with **App Attest** verification, and put the rate limit in a shared store.
