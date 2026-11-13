import { GoogleGenAI } from "@google/genai";
import type { Summary } from "./types.js";

/**
 * Gemini runs through Vertex AI using the Cloud Functions service account,
 * so there is no API key to store or leak. Model names are config so we can
 * move to a newer model without an app release.
 */
export const GEMINI_MODEL = process.env.GEMINI_MODEL ?? "gemini-3.8-flash";
export const EMBEDDING_MODEL = process.env.EMBEDDING_MODEL ?? "gemini-embedding-001";
export const EMBEDDING_DIMENSIONS = 768;

let client: GoogleGenAI | undefined;
function ai(): GoogleGenAI {
  client ??= new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT,
    location: process.env.GEMINI_LOCATION ?? "global",
  });
  return client;
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
  return values;
}

export interface Context {
  id: string;
  label: string;
  text: string;
}

export interface Answer {
  answer: string;
  usedSourceIds: string[];
  confident: boolean;
}

const ANSWER_INSTRUCTION = `You are Easy-GST, a helper that explains Indian GST, customs and foreign trade rules
to the general public in simple language.
Rules:
- Answer ONLY from the official documents provided. If they do not cover the question, say you are not sure
  and suggest checking the official website or a tax professional. Set confident=false in that case.
- Only answer questions about Indian tax, GST, customs, foreign trade or company law. Politely decline anything else.
- Never give personal tax or legal advice; give general information.
- Keep answers under 150 words. Mention document numbers you relied on.
- List the ids of the documents you actually used in usedSourceIds.
- Write the answer in the language requested.`;

const ANSWER_SCHEMA = {
  type: "object",
  properties: {
    answer: { type: "string" },
    usedSourceIds: { type: "array", items: { type: "string" } },
    confident: { type: "boolean" },
  },
  required: ["answer", "usedSourceIds", "confident"],
};

export async function answerQuestion(question: string, language: "en" | "hi", contexts: Context[]): Promise<Answer> {
  const docs = contexts.map((c) => `<document id="${c.id}" label="${c.label.replace(/"/g, "'")}">\n${c.text}\n</document>`).join("\n\n");
  const res = await ai().models.generateContent({
    model: GEMINI_MODEL,
    contents: [{
      role: "user",
      parts: [{ text: `Official documents:\n${docs || "(none found)"}\n\nLanguage: ${language === "hi" ? "Hindi" : "English"}\n\nQuestion: ${question}` }],
    }],
    config: {
      systemInstruction: ANSWER_INSTRUCTION,
      responseMimeType: "application/json",
      responseJsonSchema: ANSWER_SCHEMA,
      temperature: 0.2,
    },
  });
  if (!res.text) throw new Error("Gemini returned no text");
  const raw = JSON.parse(res.text) as Partial<Answer>;
  const known = new Set(contexts.map((c) => c.id));
  return {
    answer: String(raw.answer ?? "").trim(),
    usedSourceIds: (raw.usedSourceIds ?? []).filter((id) => known.has(id)),
    confident: raw.confident === true,
  };
}
