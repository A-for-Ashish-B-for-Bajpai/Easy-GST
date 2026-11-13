import type { Firestore } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { parseListing } from "./parse.js";
import type { SourceConfig, Update } from "./types.js";

export const USER_AGENT = "EasyGST-Collector/1.0 (public notifications reader)";

/** On a source's first run we store its whole back catalogue, but only summarise the newest few. */
export const BACKFILL_SUMMARISE_LIMIT = 15;

export type Fetcher = (url: string) => Promise<string>;

export const httpFetcher: Fetcher = async (url) => {
  const res = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, Accept: "text/html" },
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.text();
};

export interface SourceResult {
  sourceId: string;
  found: number;
  added: number;
  error?: string;
}

/**
 * Checks every source once and stores documents we haven't seen.
 * New documents get status "pending", which triggers the Gemini summary.
 * One failing site never stops the others.
 */
export async function collectAll(db: Firestore, sources: SourceConfig[], fetcher: Fetcher = httpFetcher): Promise<SourceResult[]> {
  const results: SourceResult[] = [];
  for (const source of sources) {
    const healthRef = db.collection("sources").doc(source.id);
    try {
      const html = await fetcher(source.url);
      const items = parseListing(html, source);
      if (items.length === 0) throw new Error("No rows parsed; the page layout may have changed");

      const firstRun = !(await healthRef.get()).exists;
      const added = await storeNew(db, items, firstRun);
      await healthRef.set({
        authority: source.authority,
        category: source.category,
        url: source.url,
        lastRunAt: FieldValue.serverTimestamp(),
        lastOkAt: FieldValue.serverTimestamp(),
        lastFound: items.length,
        lastAdded: added,
        lastError: null,
      }, { merge: true });
      results.push({ sourceId: source.id, found: items.length, added });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await healthRef.set({ lastRunAt: FieldValue.serverTimestamp(), lastError: message, url: source.url }, { merge: true });
      results.push({ sourceId: source.id, found: 0, added: 0, error: message });
    }
  }
  return results;
}

async function storeNew(db: Firestore, items: Update[], firstRun: boolean): Promise<number> {
  const col = db.collection("updates");
  const existing = await db.getAll(...items.map((i) => col.doc(i.id)), { fieldMask: ["id"] });
  const fresh = items.filter((_, idx) => !existing[idx].exists);
  const today = new Date().toISOString().slice(0, 10);

  // Firestore batches hold at most 500 writes.
  for (let start = 0; start < fresh.length; start += 400) {
    const batch = db.batch();
    fresh.slice(start, start + 400).forEach((item, offset) => {
      const position = start + offset; // listing pages are newest first
      const summarise = !firstRun || position < BACKFILL_SUMMARISE_LIMIT;
      batch.create(col.doc(item.id), {
        ...item,
        sortDate: item.issuedOn ?? today,
        firstSeenAt: FieldValue.serverTimestamp(),
        backfill: firstRun,
        status: summarise ? "pending" : "unsummarised",
      });
    });
    await batch.commit();
  }
  return fresh.length;
}
