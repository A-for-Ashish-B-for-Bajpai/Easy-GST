import { test } from "node:test";
import assert from "node:assert/strict";
import { validate, AskError, MAX_QUESTION_LENGTH } from "../src/ask.js";
import { parseSummary } from "../src/gemini.js";
import { searchText, topicCondition } from "../src/summarise.js";

test("validate trims, defaults language and rejects bad input", () => {
  assert.deepEqual(validate({ question: "  What is GSTR-1? " }), { question: "What is GSTR-1?", language: "en" });
  assert.equal(validate({ question: "GST दर क्या है?", language: "hi" }).language, "hi");
  assert.throws(() => validate({ question: "" }), AskError);
  assert.throws(() => validate(null), AskError);
  assert.throws(() => validate({ question: "x".repeat(MAX_QUESTION_LENGTH + 1) }), /under 500/);
});

test("parseSummary keeps at most 5 non-empty lines and requires a title", () => {
  const s = parseSummary(JSON.stringify({
    plainTitle: "Rice export rule changed",
    summaryEn: ["a", "", "b", "c", "d", "e", "f"],
    summaryHi: ["क"],
    whoIsAffected: "Rice exporters",
  }));
  assert.deepEqual(s.summaryEn, ["a", "b", "c", "d", "e"]);
  assert.throws(() => parseSummary(JSON.stringify({ summaryEn: ["a"] })), /missing/);
  assert.throws(() => parseSummary(undefined), /no text/);
});

test("searchText combines metadata, summary and a capped body", () => {
  const t = searchText(
    { title: "Amendment in export policy", number: "47", authority: "DGFT", category: "Notification" },
    { plainTitle: "Rice export rule", summaryEn: ["Line one"], summaryHi: [], whoIsAffected: "", keyFacts: "" },
    "x".repeat(10_000),
  );
  assert.match(t, /^DGFT Notification 47/);
  assert.ok(t.includes("Line one"));
  assert.ok(t.length < 4200);
});

test("topicCondition joins topics so a user gets one alert", () => {
  assert.equal(topicCondition(["gst", "gst-rates"]), "'topic-gst' in topics || 'topic-gst-rates' in topics");
});
