/**
 * Fetches every source live and prints what the parser finds, without
 * touching Firestore or Gemini. Run with: npm run collect:dry
 */
import { httpFetchHtml as httpFetcher } from "../pipeline.js";
import { parseListing } from "../parse.js";
import { SOURCES } from "../sources.js";

for (const source of SOURCES) {
  try {
    const items = parseListing(await httpFetcher(source.url), source);
    const top = items[0];
    console.log(`OK   ${source.id.padEnd(30)} ${String(items.length).padStart(4)} items  latest: ${top?.number ?? "-"} ${top?.issuedOn ?? ""} ${top?.title.slice(0, 60) ?? ""}`);
  } catch (err) {
    console.log(`FAIL ${source.id.padEnd(30)} ${err instanceof Error ? err.message : err}`);
  }
}
