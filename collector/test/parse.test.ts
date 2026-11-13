import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseListing, parseIndianDate } from "../src/parse.js";
import { SOURCES } from "../src/sources.js";

const fixture = (name: string) => readFileSync(new URL(`../../test/fixtures/${name}.html`, import.meta.url), "utf8");
const source = (id: string) => SOURCES.find((s) => s.id === id)!;

test("parseIndianDate handles both separators and rejects junk", () => {
  assert.equal(parseIndianDate("10/11/2026"), "2026-11-10");
  assert.equal(parseIndianDate(" 24-06-2025 "), "2025-06-24");
  assert.equal(parseIndianDate("2026-27"), null);
  assert.equal(parseIndianDate("40/13/2026"), null);
});

test("DGFT notifications: number, title, date and encoded PDF link", () => {
  const items = parseListing(fixture("dgft-notification"), source("dgft-notification"));
  assert.ok(items.length > 50, `expected many rows, got ${items.length}`);
  const first = items[0];
  assert.equal(first.number, "49/2026-27");
  assert.match(first.title, /Lithium-Ion Battery Black Mass/);
  assert.equal(first.issuedOn, "2026-11-10");
  assert.equal(first.pdfUrl, "https://content.dgft.gov.in/Website/dgftprod/58145d8f-19de-4e3a-b7ba-95fdb2ed5ea4/Notification%20No.%2049%20of%202026-2027.pdf");
  assert.equal(first.authority, "DGFT");
  assert.equal(new Set(items.map((i) => i.id)).size, items.length, "ids are unique");
});

for (const id of ["dgft-public-notice", "dgft-circular", "dgft-trade-notice"]) {
  test(`${id} parses with the shared DGFT layout`, () => {
    const items = parseListing(fixture(id.replace("dgft-", "dgft-")), source(id));
    assert.ok(items.length > 10);
    for (const i of items.slice(0, 10)) {
      assert.ok(i.issuedOn, `date for ${i.number}`);
      assert.ok(i.pdfUrl.startsWith("https://content.dgft.gov.in/"));
    }
  });
}

test("GST Council CGST notifications include the Hindi PDF", () => {
  const items = parseListing(fixture("gstc-cgst-tax-notification"), source("gstc-cgst-tax-notification"));
  const first = items[0];
  assert.equal(first.number, "11/2025-Central Tax");
  assert.equal(first.title, "Seeks to notify Central Goods and Services Tax (Second Amendment) Rules 2025");
  assert.equal(first.pdfUrl, "https://www.gstcouncil.gov.in/sites/default/files/2025-04/gst-ct-11-2025.pdf");
  assert.equal(first.pdfUrlHindi, "https://www.gstcouncil.gov.in/sites/default/files/2025-04/gst-ct-11h-2025.pdf");
  assert.equal(first.issuedOn, null);
});

test("GST Council rate notifications", () => {
  const items = parseListing(fixture("gstc-cgst-rate-notification"), source("gstc-cgst-rate-notification"));
  assert.equal(items[0].number, "08/2025-Central Tax (Rate)");
  assert.match(items[0].title, /55th GST Council/);
  assert.deepEqual(items[0].topics, ["gst", "gst-rates"]);
});

test("GST Council circulars have dates", () => {
  const items = parseListing(fixture("gstc-cgst-circulars"), source("gstc-cgst-circular"));
  assert.equal(items[0].number, "250/07/2025-GST");
  assert.equal(items[0].issuedOn, "2025-06-24");
});

test("GST Council press release title drops the size note", () => {
  const items = parseListing(fixture("gstc-press-release"), source("gstc-press-release"));
  assert.equal(items.length, 1);
  assert.equal(items[0].title, "Press Release Regarding Recommendations of the 57th Meeting of the GST Council");
  assert.equal(items[0].issuedOn, "2026-10-08");
});
