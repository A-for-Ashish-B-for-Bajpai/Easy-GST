/**
 * One collector run, used by the GitHub Actions workflow:
 *   DATA_DIR=../data-branch GEMINI_API_KEY=... node lib/run.js
 * Without GEMINI_API_KEY it still collects, and leaves documents pending.
 */
import { embed, isQuotaError, summarisePdf } from "./gemini.js";
import { collect, DEFAULT_MAX_SUMMARIES_PER_RUN, httpFetchHtml, httpFetchPdf, summarisePending, type Deps } from "./pipeline.js";
import { SOURCES } from "./sources.js";
import { loadBookkeeping, loadData, saveData } from "./store.js";

const dir = process.env.DATA_DIR ?? "data";
const maxPerRun = Number(process.env.MAX_SUMMARIES_PER_RUN ?? DEFAULT_MAX_SUMMARIES_PER_RUN);

const deps: Deps = {
  fetchHtml: httpFetchHtml,
  fetchPdf: httpFetchPdf,
  summarise: summarisePdf,
  embed: (text) => embed(text, "document"),
  isQuotaError,
  log: (m) => console.log(m),
};

const data = loadData(dir);
data.updates = loadBookkeeping(dir, data.updates);

await collect(data, SOURCES, deps);
const summarised = process.env.GEMINI_API_KEY ? await summarisePending(data, deps, maxPerRun) : 0;
if (!process.env.GEMINI_API_KEY) console.log("GEMINI_API_KEY not set: skipping summaries");
saveData(dir, data);

const pending = data.updates.filter((u) => u.status === "pending").length;
console.log(`Done: ${data.updates.length} documents, ${summarised} summarised this run, ${pending} waiting.`);

// Fail the run (so GitHub emails you) only if every source failed.
if (data.sources.length > 0 && data.sources.every((s) => s.lastError)) process.exit(1);
