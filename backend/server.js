// MedList extraction proxy. POST /extract {"text": "...", "language": "nl"|"en"} -> {"medications": [...]}
//
// Privacy: request bodies and model output are never logged or stored. Only method, status and duration are logged.
// The Anthropic API key lives in the environment of this server, never in the app.
import http from "node:http";
import { createExtractor, ExtractionError, MAX_INPUT_CHARS } from "./extract.js";

const PORT = Number(process.env.PORT || 8787);
const CLIENT_TOKEN = process.env.MEDLIST_CLIENT_TOKEN || ""; // coarse gate; replace with App Attest (TODO.md)
const RATE_LIMIT_PER_MINUTE = Number(process.env.MEDLIST_RATE_LIMIT || 20);
const MAX_BODY_BYTES = MAX_INPUT_CHARS * 4 + 1024;

const extract = createExtractor();
const hits = new Map(); // ip -> timestamps (in memory; use a shared store when running more than one instance)

function rateLimited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > RATE_LIMIT_PER_MINUTE;
}

function send(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json", "Cache-Control": "no-store" });
  res.end(JSON.stringify(body));
}

async function readJSON(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new ExtractionError("too_large", 413);
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new ExtractionError("bad_json", 400);
  }
}

const server = http.createServer(async (req, res) => {
  const started = Date.now();
  let status = 500;
  try {
    if (req.method === "GET" && req.url === "/healthz") return send(res, (status = 200), { ok: true });
    if (req.method !== "POST" || req.url !== "/extract") return send(res, (status = 404), { error: "not_found" });
    if (CLIENT_TOKEN && req.headers["x-medlist-client"] !== CLIENT_TOKEN) return send(res, (status = 401), { error: "unauthorized" });
    const ip = req.headers["x-forwarded-for"]?.split(",")[0].trim() || req.socket.remoteAddress;
    if (rateLimited(ip)) return send(res, (status = 429), { error: "rate_limited" });

    const body = await readJSON(req);
    const result = await extract(body.text, body.language === "nl" ? "nl" : "en");
    send(res, (status = 200), result);
  } catch (error) {
    if (error instanceof ExtractionError) {
      send(res, (status = error.status), { error: error.code });
    } else {
      send(res, (status = 500), { error: "internal" });
    }
  } finally {
    console.log(`${req.method} ${req.url} ${status} ${Date.now() - started}ms`);
  }
});

server.listen(PORT, () => console.log(`medlist proxy listening on :${PORT}`));
