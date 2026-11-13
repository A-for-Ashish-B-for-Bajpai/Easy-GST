import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { normalise, parseSummary } from "../src/gemini.js";
import { BACKFILL_SUMMARISE_LIMIT, collect, MAX_ATTEMPTS, monthFromUrl, summarisePending, type Deps } from "../src/pipeline.js";
import { SOURCES } from "../src/sources.js";
import { loadBookkeeping, loadData, saveData, type DataFiles } from "../src/store.js";

const fixture = (name: string) => readFileSync(new URL(`../../test/fixtures/${name}.html`, import.meta.url), "utf8");
const dgft = SOURCES.filter((s) => s.id === "dgft-circular");
const empty = (): DataFiles => ({ updates: [], chat: [], sources: [] });

function fakeDeps(over: Partial<Deps> = {}): Deps & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    fetchHtml: async () => fixture("dgft-circular"),
    fetchPdf: async (url) => { calls.push(url); return new Uint8Array([1, 2, 3]); },
    summarise: async (_pdf, meta) => ({
      plainTitle: `Plain ${meta.number}`,
      summaryEn: ["What changed"],
      summaryHi: ["क्या बदला"],
      whoIsAffected: "Importers",
      keyFacts: "HS 71069221, silver",
    }),
    embed: async () => normalise([3, 4]),
    isQuotaError: (err) => String(err).includes("429"),
    log: () => {},
    ...over,
  };
}

test("first run keeps the back catalogue but only queues the newest for summaries", async () => {
  const data = empty();
  await collect(data, dgft, fakeDeps(), new Date("2026-11-13T10:00:00Z"));
  assert.ok(data.updates.length > BACKFILL_SUMMARISE_LIMIT);
  assert.equal(data.updates.filter((u) => u.status === "pending").length, BACKFILL_SUMMARISE_LIMIT);
  assert.equal(data.sources[0].lastError, null);
  assert.equal(data.updates[0].firstSeenOn, "2026-11-13");

  // Second run with the same page adds nothing.
  await collect(data, dgft, fakeDeps());
  assert.equal(data.sources[0].lastAdded, 0);
});

test("a failing site is recorded and does not throw", async () => {
  const data = empty();
  await collect(data, dgft, fakeDeps({ fetchHtml: async () => { throw new Error("HTTP 403"); } }));
  assert.equal(data.sources[0].lastError, "HTTP 403");
  assert.equal(data.updates.length, 0);
});

test("summaries respect the per-run cap and fill the chat index", async () => {
  const data = empty();
  await collect(data, dgft, fakeDeps());
  const deps = fakeDeps();
  const done = await summarisePending(data, deps, 3);
  assert.equal(done, 3);
  const ready = data.updates.filter((u) => u.status === "ready");
  assert.equal(ready.length, 3);
  assert.equal(ready[0].summaryHi?.[0], "क्या बदला");
  assert.equal(data.chat.length, 3);
  assert.deepEqual(data.chat[0].e, [0.6, 0.8]);
  // Scanned PDF (no text layer): chat text falls back to Gemini's key facts.
  assert.match(data.chat[0].t, /HS 71069221/);
});

test("free quota stops the run and leaves the rest pending", async () => {
  const data = empty();
  await collect(data, dgft, fakeDeps());
  let n = 0;
  const deps = fakeDeps({ summarise: async () => { if (++n > 2) throw new Error("429 RESOURCE_EXHAUSTED"); return parseSummary(JSON.stringify({ plainTitle: "t", summaryEn: ["a"], summaryHi: [], whoIsAffected: "", keyFacts: "" })); } });
  assert.equal(await summarisePending(data, deps, 10), 2);
  assert.equal(data.updates.filter((u) => u.status === "pending").length, BACKFILL_SUMMARISE_LIMIT - 2);
  assert.equal(data.updates.filter((u) => u.status === "failed").length, 0);
});

test("other errors are retried, then marked failed; bookkeeping survives a save", async () => {
  const dir = mkdtempSync(join(tmpdir(), "easygst-"));
  let data = empty();
  await collect(data, dgft, fakeDeps());
  const broken = fakeDeps({ fetchPdf: async () => { throw new Error("HTTP 404 for PDF"); } });
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    await summarisePending(data, broken, 1);
    saveData(dir, data);
    data = loadData(dir);
    data.updates = loadBookkeeping(dir, data.updates);
  }
  const failed = data.updates.filter((u) => u.status === "failed");
  assert.equal(failed.length, 1);
  assert.equal(failed[0].attempts, MAX_ATTEMPTS);
  // updates.json itself has no bookkeeping fields.
  const raw = JSON.parse(readFileSync(join(dir, "updates.json"), "utf8"));
  assert.equal(raw.updates[0].attempts, undefined);
});

test("parseSummary keeps at most 5 non-empty lines and requires a title", () => {
  const s = parseSummary(JSON.stringify({ plainTitle: "Rice", summaryEn: ["a", "", "b", "c", "d", "e", "f"], summaryHi: ["क"], whoIsAffected: "x", keyFacts: "k" }));
  assert.deepEqual(s.summaryEn, ["a", "b", "c", "d", "e"]);
  assert.throws(() => parseSummary(JSON.stringify({ summaryEn: ["a"] })), /missing/);
});

test("undated documents are ordered by their upload folder month", async () => {
  assert.equal(monthFromUrl("https://www.gstcouncil.gov.in/sites/default/files/2025-04/gst-ct-11-2025.pdf"), "2025-04-01");
  assert.equal(monthFromUrl("https://content.dgft.gov.in/Website/x/a.pdf"), null);
  const data = empty();
  const gst = SOURCES.filter((s) => s.id === "gstc-cgst-tax-notification");
  await collect(data, gst, fakeDeps({ fetchHtml: async () => fixture("gstc-cgst-tax-notification") }), new Date("2026-11-13T10:00:00Z"));
  assert.equal(data.updates[0].sortDate, "2025-04-01");
  assert.equal(data.updates[0].issuedOn, null);
});
