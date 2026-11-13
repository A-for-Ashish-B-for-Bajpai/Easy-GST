import { extractText, getDocumentProxy } from "unpdf";
import { parseListing } from "./parse.js";
import type { ChatEntry, DataFiles, SourceHealth, StoredUpdate } from "./store.js";
import { sortUpdates } from "./store.js";
import type { SourceConfig, Summary, Update } from "./types.js";

export const USER_AGENT = "EasyGST-Collector/1.0 (personal reader of public notifications)";

/** On a source's first run we keep its whole back catalogue but only summarise the newest few. */
export const BACKFILL_SUMMARISE_LIMIT = 10;
/** Keeps each run well inside the Gemini free tier. Leftovers wait for the next run. */
export const DEFAULT_MAX_SUMMARIES_PER_RUN = 12;
export const MAX_ATTEMPTS = 3;
const MAX_PDF_BYTES = 18 * 1024 * 1024;
const CHAT_TEXT_CHARS = 3000;

/** Everything that touches the network or Gemini, so tests can swap it out. */
export interface Deps {
  fetchHtml(url: string): Promise<string>;
  fetchPdf(url: string): Promise<Uint8Array>;
  summarise(pdf: Uint8Array, meta: { title: string; number: string | null; authority: string }): Promise<Summary>;
  embed(text: string): Promise<number[]>;
  isQuotaError(err: unknown): boolean;
  log(message: string): void;
}

export const httpFetchHtml = async (url: string): Promise<string> => {
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT, Accept: "text/html" }, signal: AbortSignal.timeout(30_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.text();
};

export const httpFetchPdf = async (url: string): Promise<Uint8Array> => {
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} for PDF`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf.byteLength > MAX_PDF_BYTES) throw new Error(`PDF too large (${buf.byteLength} bytes)`);
  return buf;
};

/** Plain text of a PDF. Scanned PDFs give little or nothing; Gemini's key facts fill in. */
export async function pdfText(pdf: Uint8Array): Promise<string> {
  try {
    const { text } = await extractText(await getDocumentProxy(new Uint8Array(pdf)), { mergePages: true });
    return text.replace(/\s+/g, " ").trim();
  } catch {
    return "";
  }
}

const today = (now: Date) => new Date(now.getTime() + 5.5 * 3600_000).toISOString().slice(0, 10); // India date

/** Step 1: read every source and add documents we haven't seen. One failing site never stops the others. */
export async function collect(data: DataFiles, sources: SourceConfig[], deps: Deps, now = new Date()): Promise<void> {
  const known = new Set(data.updates.map((u) => u.id));
  for (const source of sources) {
    const health: SourceHealth = data.sources.find((s) => s.id === source.id) ?? { id: source.id, url: source.url, lastRunAt: "", lastFound: 0, lastAdded: 0, lastError: null };
    health.lastRunAt = now.toISOString();
    health.url = source.url;
    try {
      const items = parseListing(await deps.fetchHtml(source.url), source);
      if (items.length === 0) throw new Error("No rows parsed; the page layout may have changed");
      const firstRun = !data.updates.some((u) => u.sourceId === source.id);
      const fresh = items.filter((i) => !known.has(i.id));
      fresh.forEach((item, position) => {
        known.add(item.id);
        data.updates.push(toStored(item, firstRun && position >= BACKFILL_SUMMARISE_LIMIT ? "unsummarised" : "pending", now));
      });
      Object.assign(health, { lastOkAt: now.toISOString(), lastFound: items.length, lastAdded: fresh.length, lastError: null });
      deps.log(`${source.id}: ${items.length} found, ${fresh.length} new`);
    } catch (err) {
      health.lastError = err instanceof Error ? err.message : String(err);
      deps.log(`${source.id}: FAILED ${health.lastError}`);
    }
    if (!data.sources.includes(health)) data.sources.push(health);
  }
}

/**
 * Some lists (GST Council notifications) have no date column, but their PDFs
 * sit in upload folders like /files/2025-04/. That month is close enough to
 * order the feed, so old documents don't show up as today's.
 */
export function monthFromUrl(url: string): string | null {
  const m = url.match(/\/(20\d{2})-(0[1-9]|1[0-2])\//);
  return m ? `${m[1]}-${m[2]}-01` : null;
}

function toStored(item: Update, status: StoredUpdate["status"], now: Date): StoredUpdate {
  const seen = today(now);
  return { ...item, sortDate: item.issuedOn ?? monthFromUrl(item.pdfUrl) ?? seen, firstSeenOn: seen, status, attempts: 0 };
}

/** Step 2: summarise pending documents, newest first, until the per-run cap or the free quota runs out. */
export async function summarisePending(data: DataFiles, deps: Deps, maxPerRun = DEFAULT_MAX_SUMMARIES_PER_RUN): Promise<number> {
  const queue = sortUpdates(data.updates).filter((u) => u.status === "pending");
  let done = 0;
  // The cap counts tries, not successes, so a run of broken PDFs can't use up the free quota.
  for (const u of queue.slice(0, maxPerRun)) {
    try {
      const pdf = await deps.fetchPdf(u.pdfUrl);
      const [summary, text] = await Promise.all([deps.summarise(pdf, u), pdfText(pdf)]);
      const body = text.length >= 200 ? text : summary.keyFacts;
      const chatText = [`${u.authority} ${u.category} ${u.number ?? ""}`.trim(), u.title, summary.plainTitle, ...summary.summaryEn, body]
        .join("\n").slice(0, CHAT_TEXT_CHARS);
      const vector = await deps.embed(chatText);

      Object.assign(u, {
        plainTitle: summary.plainTitle,
        summaryEn: summary.summaryEn,
        summaryHi: summary.summaryHi,
        whoIsAffected: summary.whoIsAffected,
        status: "ready",
        error: undefined,
      });
      const entry: ChatEntry = { id: u.id, e: vector, t: chatText };
      data.chat = [...data.chat.filter((c) => c.id !== u.id), entry];
      done++;
      deps.log(`summarised ${u.id} (${u.authority} ${u.number ?? u.title.slice(0, 40)})`);
    } catch (err) {
      if (deps.isQuotaError(err)) {
        deps.log("Gemini free quota reached; the rest will be summarised next run");
        break;
      }
      u.attempts += 1;
      u.error = err instanceof Error ? err.message : String(err);
      if (u.attempts >= MAX_ATTEMPTS) u.status = "failed";
      deps.log(`could not summarise ${u.id}: ${u.error}`);
    }
  }
  return done;
}
