import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger, setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { ask, AskError } from "./ask.js";
import { collectAll } from "./collect.js";
import { SOURCES } from "./sources.js";
import { summariseUpdate } from "./summarise.js";

initializeApp();
const db = getFirestore();

// Mumbai: closest to the government sites and to users.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

/** Checks all sources every 6 hours, India time. */
export const collectUpdates = onSchedule(
  { schedule: "every 6 hours", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const results = await collectAll(db, SOURCES);
    for (const r of results) {
      if (r.error) logger.error("Source failed", r);
      else logger.info("Source checked", r);
    }
  },
);

/** Summarises each new document with Gemini and alerts followers. */
export const summariseNewUpdate = onDocumentCreated(
  { document: "updates/{id}", timeoutSeconds: 300, memory: "1GiB", retry: false },
  async (event) => {
    if (event.data?.get("status") !== "pending") return;
    try {
      await summariseUpdate(db, getMessaging(), event.params.id);
    } catch (err) {
      logger.error("Summary failed", { id: event.params.id, err: String(err) });
    }
  },
);

/** "Ask a tax question". App Check keeps other clients from using our Gemini quota. */
export const askTaxQuestion = onCall(
  { enforceAppCheck: true, timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please restart the app and try again.");
    try {
      return await ask(db, request.auth.uid, request.data);
    } catch (err) {
      if (err instanceof AskError) throw new HttpsError(err.code, err.message);
      logger.error("Ask failed", { err: String(err) });
      throw new HttpsError("internal", "Sorry, something went wrong. Please try again.");
    }
  },
);
