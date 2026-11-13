import type { Firestore } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { answerQuestion, embed, type Context } from "./gemini.js";

export const DAILY_QUESTION_LIMIT = 20;
export const MAX_QUESTION_LENGTH = 500;
const CONTEXT_DOCS = 6;

export interface AskRequest {
  question: string;
  language: "en" | "hi";
}

export interface AskResponse {
  answer: string;
  confident: boolean;
  sources: { id: string; title: string; number: string | null; authority: string; pdfUrl: string }[];
  remainingToday: number;
}

export class AskError extends Error {
  constructor(public code: "invalid-argument" | "resource-exhausted", message: string) {
    super(message);
  }
}

export function validate(input: unknown): AskRequest {
  const data = (input ?? {}) as Record<string, unknown>;
  const question = typeof data.question === "string" ? data.question.trim() : "";
  if (question.length < 3) throw new AskError("invalid-argument", "Please type a question.");
  if (question.length > MAX_QUESTION_LENGTH) throw new AskError("invalid-argument", `Please keep questions under ${MAX_QUESTION_LENGTH} characters.`);
  return { question, language: data.language === "hi" ? "hi" : "en" };
}

/** Counts today's questions for a user (India time) and refuses past the daily limit. */
export async function takeQuota(db: Firestore, uid: string, now = new Date()): Promise<number> {
  const day = new Date(now.getTime() + 5.5 * 3600_000).toISOString().slice(0, 10);
  const ref = db.collection("usage").doc(`${uid}_${day}`);
  return db.runTransaction(async (tx) => {
    const used = ((await tx.get(ref)).get("questions") as number | undefined) ?? 0;
    if (used >= DAILY_QUESTION_LIMIT) {
      throw new AskError("resource-exhausted", `You've reached today's limit of ${DAILY_QUESTION_LIMIT} questions. Please try again tomorrow.`);
    }
    tx.set(ref, { uid, day, questions: used + 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return DAILY_QUESTION_LIMIT - used - 1;
  });
}

export async function ask(db: Firestore, uid: string, input: unknown): Promise<AskResponse> {
  const req = validate(input);
  const remainingToday = await takeQuota(db, uid);

  const queryVector = await embed(req.question, "query");
  const nearest = await db.collection("updates")
    .findNearest({ vectorField: "embedding", queryVector, limit: CONTEXT_DOCS, distanceMeasure: "COSINE" })
    .get();

  const contexts: Context[] = [];
  const byId = new Map<string, FirebaseFirestore.DocumentData>();
  await Promise.all(nearest.docs.map(async (doc) => {
    const d = doc.data();
    byId.set(doc.id, d);
    const body = ((await doc.ref.collection("content").doc("text").get()).get("text") as string | undefined) ?? "";
    contexts.push({
      id: doc.id,
      label: `${d.authority} ${d.category} ${d.number ?? ""}`.trim(),
      text: [d.title, ...(d.summaryEn ?? []), body.slice(0, 6000)].join("\n"),
    });
  }));

  const result = await answerQuestion(req.question, req.language, contexts);

  return {
    answer: result.answer,
    confident: result.confident,
    remainingToday,
    sources: result.usedSourceIds.map((id) => {
      const d = byId.get(id)!;
      return { id, title: d.plainTitle || d.title, number: d.number ?? null, authority: d.authority, pdfUrl: d.pdfUrl };
    }),
  };
}
