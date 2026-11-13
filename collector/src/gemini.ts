import { GoogleGenAI } from "@google/genai";
import type { Summary } from "./types.js";

/**
 * Gemini through the free tier of the Gemini API (Google AI Studio key).
 * The key comes from the GEMINI_API_KEY secret in GitHub Actions and is never
 * written to the repository. Model names are config so a newer model, or one
 * with a bigger free quota, can be used without code changes.
 */
export const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-3.8-flash";
export const EMBEDDING_MODEL = process.env.EMBEDDING_MODEL || "gemini-embedding-001";
/** Small vectors keep chat-index.json small enough for a phone to download. */
export const EMBEDDING_DIMENSIONS = 256;

let client: GoogleGenAI | undefined;
function ai(): GoogleGenAI {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");
  client ??= new GoogleGenAI({ apiKey });
  return client;
}

/** True when Gemini refused because the free quota for now is used up. */
export function isQuotaError(err: unknown): boolean {
  const e = err as { status?: number; message?: string } | undefined;
  return e?.status === 429 || /RESOURCE_EXHAUSTED|quota|rate limit/i.test(e?.message ?? "");
}

/** Scales a vector to length 1, so a dot product is the cosine similarity. Rounded to keep files small. */
export function normalise(v: number[]): number[] {
  const len = Math.hypot(...v) || 1;
  return v.map((x) => Math.round((x / len) * 10_000) / 10_000);
}

const SUMMARY_INSTRUCTION = `You explain Indian government tax and trade documents to ordinary people
(small shop owners, traders, salaried people, students). Use simple words, no legal jargon.
Never invent facts that are not in the document. If the document is unclear, say so.
Do not give personal tax advice.`;

const SUMMARY_SCHEMA = {
  type: "object",
  properties: {
    plainTitle: { type: "string", description: "Short plain title, at most 12 words." },
    summaryEn: { type: "array", items: { type: "string" }, minItems: 2, maxItems: 5, description: "3 to 5 short plain-English lines: what changed, from when, what to do." },
    summaryHi: { type: "array", items: { type: "string" }, minItems: 2, maxItems: 5, description: "The same lines in simple Hindi (Devanagari)." },
    whoIsAffected: { type: "string", description: "One plain sentence on who this affects." },
    keyFacts: { type: "string", description: "Up to 250 words listing the concrete facts: notification numbers, HS codes, rates, dates, forms, amounts. English." },
  },
  required: ["plainTitle", "summaryEn", "summaryHi", "whoIsAffected", "keyFacts"],
};

/** Summarises one official PDF. Gemini reads the PDF directly, so scanned documents work too. */
export async function summarisePdf(pdf: Uint8Array, meta: { title: string; number: string | null; authority: string }): Promise<Summary> {
  const res = await ai().models.generateContent({
    model: GEMINI_MODEL,
    contents: [{
      role: "user",
      parts: [
        { inlineData: { mimeType: "application/pdf", data: Buffer.from(pdf).toString("base64") } },
        { text: `This is ${meta.authority} document ${meta.number ?? ""} titled "${meta.title}". Summarise it.` },
      ],
    }],
    config: {
      systemInstruction: SUMMARY_INSTRUCTION,
      responseMimeType: "application/json",
      responseJsonSchema: SUMMARY_SCHEMA,
      temperature: 0.2,
    },
  });
  return parseSummary(res.text);
}

export function parseSummary(text: string | undefined): Summary {
  if (!text) throw new Error("Gemini returned no text");
  const raw = JSON.parse(text) as Partial<Summary>;
  const lines = (v: unknown) => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string" && x.trim() !== "").slice(0, 5) : []);
  const summary: Summary = {
    plainTitle: String(raw.plainTitle ?? "").trim(),
    summaryEn: lines(raw.summaryEn),
    summaryHi: lines(raw.summaryHi),
    whoIsAffected: String(raw.whoIsAffected ?? "").trim(),
    keyFacts: String(raw.keyFacts ?? "").trim().slice(0, 3000),
  };
  if (!summary.plainTitle || summary.summaryEn.length === 0) throw new Error("Gemini summary missing fields");
  return summary;
}

export async function embed(text: string, kind: "document" | "query"): Promise<number[]> {
  const res = await ai().models.embedContent({
    model: EMBEDDING_MODEL,
    contents: [text.slice(0, 8000)],
    config: {
      outputDimensionality: EMBEDDING_DIMENSIONS,
      taskType: kind === "document" ? "RETRIEVAL_DOCUMENT" : "RETRIEVAL_QUERY",
    },
  });
  const values = res.embeddings?.[0]?.values;
  if (!values?.length) throw new Error("Gemini returned no embedding");
  return normalise(values);
}
