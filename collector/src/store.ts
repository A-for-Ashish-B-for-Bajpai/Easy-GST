import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { Summary, Update } from "./types.js";

/**
 * Everything is kept as JSON files on the repository's `data` branch, which
 * GitHub serves for free. The app downloads:
 *   updates.json     feed: every document, with its summary when ready
 *   chat-index.json  for "Ask a tax question": vectors + text of summarised documents
 *   sources.json     health of each collector
 */

export type Status = "pending" | "ready" | "failed" | "unsummarised";

export interface StoredUpdate extends Update, Partial<Omit<Summary, "keyFacts">> {
  /** Date used for ordering: issue date when the site gives one, else the day we first saw it. */
  sortDate: string;
  firstSeenOn: string;
  status: Status;
  attempts: number;
  error?: string;
}

export interface ChatEntry {
  id: string;
  /** Unit-length embedding (EMBEDDING_DIMENSIONS numbers). */
  e: number[];
  /** Text Gemini answers from: title, summary and the start of the document. */
  t: string;
}

export interface SourceHealth {
  id: string;
  url: string;
  lastRunAt: string;
  lastOkAt?: string;
  lastFound: number;
  lastAdded: number;
  lastError: string | null;
}

export interface DataFiles {
  updates: StoredUpdate[];
  chat: ChatEntry[];
  sources: SourceHealth[];
}

const FILES = { updates: "updates.json", chat: "chat-index.json", sources: "sources.json" } as const;

function readJson<T>(path: string, fallback: T): T {
  return existsSync(path) ? (JSON.parse(readFileSync(path, "utf8")) as T) : fallback;
}

export function loadData(dir: string): DataFiles {
  return {
    updates: readJson<{ updates: StoredUpdate[] }>(join(dir, FILES.updates), { updates: [] }).updates,
    chat: readJson<{ entries: ChatEntry[] }>(join(dir, FILES.chat), { entries: [] }).entries,
    sources: readJson<{ sources: SourceHealth[] }>(join(dir, FILES.sources), { sources: [] }).sources,
  };
}

/** Newest first, then most recently seen. */
export function sortUpdates(updates: StoredUpdate[]): StoredUpdate[] {
  return [...updates].sort((a, b) => b.sortDate.localeCompare(a.sortDate) || b.firstSeenOn.localeCompare(a.firstSeenOn));
}

export function saveData(dir: string, data: DataFiles, now = new Date()): void {
  mkdirSync(dir, { recursive: true });
  const generatedAt = now.toISOString();
  // Bookkeeping fields stay out of what the app downloads.
  const updates = sortUpdates(data.updates).map(({ attempts: _a, error: _e, ...rest }) => rest);
  writeFileSync(join(dir, FILES.updates), JSON.stringify({ generatedAt, updates }));
  writeFileSync(join(dir, FILES.chat), JSON.stringify({ generatedAt, entries: data.chat }));
  writeFileSync(join(dir, FILES.sources), JSON.stringify({ generatedAt, sources: data.sources }, null, 2));
  // Bookkeeping kept separately so failed documents are retried a limited number of times.
  const bookkeeping = Object.fromEntries(data.updates.filter((u) => u.attempts || u.error).map((u) => [u.id, { attempts: u.attempts, error: u.error }]));
  writeFileSync(join(dir, "state.json"), JSON.stringify(bookkeeping, null, 2));
}

/** Puts back attempts/error that saveData keeps out of updates.json. */
export function loadBookkeeping(dir: string, updates: StoredUpdate[]): StoredUpdate[] {
  const state = readJson<Record<string, { attempts?: number; error?: string }>>(join(dir, "state.json"), {});
  return updates.map((u) => ({ ...u, attempts: state[u.id]?.attempts ?? 0, error: state[u.id]?.error }));
}
