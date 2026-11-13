import type { Firestore } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import { extractText, getDocumentProxy } from "unpdf";
import { USER_AGENT } from "./collect.js";
import { embed, summarisePdf } from "./gemini.js";
import type { Summary, Update } from "./types.js";

const MAX_PDF_BYTES = 18 * 1024 * 1024; // Gemini inline limit is about 20 MB
const MAX_STORED_TEXT = 20_000;

export async function downloadPdf(url: string): Promise<Uint8Array> {
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} for PDF`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (buf.byteLength > MAX_PDF_BYTES) throw new Error(`PDF too large (${buf.byteLength} bytes)`);
  return buf;
}

/** Plain text of a PDF for search. Scanned PDFs return little or nothing, which is fine. */
export async function pdfText(pdf: Uint8Array): Promise<string> {
  try {
    const doc = await getDocumentProxy(new Uint8Array(pdf));
    const { text } = await extractText(doc, { mergePages: true });
    return text.replace(/\s+/g, " ").trim();
  } catch {
    return "";
  }
}

/** What we embed for search: enough to match a question to the right document. */
export function searchText(update: Pick<Update, "title" | "number" | "authority" | "category">, summary: Summary, body: string): string {
  return [
    `${update.authority} ${update.category} ${update.number ?? ""}`,
    update.title,
    summary.plainTitle,
    ...summary.summaryEn,
    body.slice(0, 4000),
  ].join("\n");
}

/** FCM allows up to 5 topics in a condition; we have at most 2 per source. */
export function topicCondition(topics: string[]): string {
  return topics.slice(0, 5).map((t) => `'topic-${t}' in topics`).join(" || ");
}

/**
 * Turns a "pending" update into a "ready" one: summary in English and Hindi,
 * a search embedding, and the PDF text for the chat. Sends a push alert to
 * followers of its topics unless it came from the first back-catalogue load.
 */
export async function summariseUpdate(db: Firestore, messaging: Messaging, id: string): Promise<void> {
  const ref = db.collection("updates").doc(id);
  const snap = await ref.get();
  const update = snap.data() as (Update & { status: string; backfill?: boolean }) | undefined;
  if (!update || update.status !== "pending") return;

  try {
    const pdf = await downloadPdf(update.pdfUrl);
    const [summary, text] = await Promise.all([summarisePdf(pdf, update), pdfText(pdf)]);
    // Many DGFT PDFs are scans with no text layer; fall back to Gemini's own reading of the facts.
    const body = text.length >= 200 ? text : summary.keyFacts;
    const vector = await embed(searchText(update, summary, body), "document");

    await ref.collection("content").doc("text").set({ text: body.slice(0, MAX_STORED_TEXT) });
    await ref.update({
      plainTitle: summary.plainTitle,
      summaryEn: summary.summaryEn,
      summaryHi: summary.summaryHi,
      whoIsAffected: summary.whoIsAffected,
      embedding: FieldValue.vector(vector),
      status: "ready",
      summarisedAt: FieldValue.serverTimestamp(),
    });

    if (!update.backfill && update.topics.length > 0) {
      // One message with a condition, so people who follow two of its topics get it once.
      await messaging.send({
        condition: topicCondition(update.topics),
        notification: { title: summary.plainTitle, body: summary.summaryEn[0] },
        data: { updateId: id },
        android: { priority: "normal" },
      });
    }
  } catch (err) {
    await ref.update({ status: "failed", error: err instanceof Error ? err.message : String(err) });
    throw err;
  }
}
