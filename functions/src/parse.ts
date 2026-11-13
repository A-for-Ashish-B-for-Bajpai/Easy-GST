import { createHash } from "node:crypto";
import * as cheerio from "cheerio";
import type { SourceConfig, Update } from "./types.js";

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

/** Turns "10/11/2026" or "24-06-2025" into "2026-11-10". Returns null if it doesn't look like a date. */
export function parseIndianDate(raw: string): string | null {
  const m = clean(raw).match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})/);
  if (!m) return null;
  const [, d, mo, y] = m;
  const day = Number(d), month = Number(mo);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
}

/** A stable id for a document: the same PDF always maps to the same Firestore doc. */
export function updateId(sourceId: string, pdfUrl: string): string {
  return createHash("sha1").update(`${sourceId}|${pdfUrl}`).digest("hex").slice(0, 20);
}

function absolute(href: string, base: string): string {
  // DGFT links contain raw spaces; URL() encodes them.
  return new URL(href.trim(), base).toString();
}

/**
 * Reads every row of the listing table(s) on a page and returns the
 * documents it links to. Rows without a PDF link or title are skipped.
 */
export function parseListing(html: string, source: SourceConfig): Update[] {
  const $ = cheerio.load(html);
  const out: Update[] = [];
  const seen = new Set<string>();
  const { columns } = source;

  $("tbody tr").each((_, tr) => {
    const cells = $(tr).children("td");
    if (cells.length <= columns.title) return;

    const cellText = (i?: number) => (i === undefined ? "" : clean(cells.eq(i).text()));
    const pdfIn = (i?: number) => {
      const scope = i === undefined ? $(tr) : cells.eq(i);
      const href = scope.find("a[href]").filter((_, a) => /\.pdf(\?|$)/i.test($(a).attr("href") ?? "")).first().attr("href");
      return href ? absolute(href, source.url) : null;
    };

    const pdfUrl = pdfIn(columns.pdf);
    // Drop file-size notes like "(Size:536.57 KB)" that some sites put in the title cell.
    const title = cellText(columns.title).replace(/\(\s*(Format|Size)\s*:[^)]*\)/gi, "").trim();
    if (!pdfUrl || !title) return;

    const id = updateId(source.id, pdfUrl);
    if (seen.has(id)) return;
    seen.add(id);

    out.push({
      id,
      sourceId: source.id,
      authority: source.authority,
      category: source.category,
      topics: source.topics,
      number: cellText(columns.number) || null,
      title,
      issuedOn: columns.date === undefined ? null : parseIndianDate(cellText(columns.date)),
      pdfUrl,
      pdfUrlHindi: columns.pdfHindi === undefined ? null : pdfIn(columns.pdfHindi),
      listingUrl: source.url,
    });
  });

  return out;
}
