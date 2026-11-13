import type { SourceConfig } from "./types.js";

/**
 * Listing pages we collect from. Column positions were checked against the
 * live pages on 2026-11-13 (see test/fixtures). If a site changes its layout,
 * the parser test for that source fails and the health check flags it.
 *
 * Not yet included:
 * - CBIC (taxinformation.cbic.gov.in): resets connections from our test
 *   servers, likely blocks non-Indian IPs. Retry from asia-south1.
 * - MCA (mca.gov.in): returns 403 to automated requests.
 */
const DGFT_COLUMNS = { number: 1, title: 3, date: 4, pdf: 6 } as const;

export const SOURCES: SourceConfig[] = [
  {
    id: "dgft-notification",
    authority: "DGFT",
    category: "Notification",
    topics: ["foreign-trade"],
    url: "https://www.dgft.gov.in/CP/?opt=notification",
    columns: DGFT_COLUMNS,
    dateFormat: "dd/mm/yyyy",
  },
  {
    id: "dgft-public-notice",
    authority: "DGFT",
    category: "Public Notice",
    topics: ["foreign-trade"],
    url: "https://www.dgft.gov.in/CP/?opt=public-notice",
    columns: DGFT_COLUMNS,
    dateFormat: "dd/mm/yyyy",
  },
  {
    id: "dgft-circular",
    authority: "DGFT",
    category: "Circular",
    topics: ["foreign-trade"],
    url: "https://www.dgft.gov.in/CP/?opt=circular",
    columns: DGFT_COLUMNS,
    dateFormat: "dd/mm/yyyy",
  },
  {
    id: "dgft-trade-notice",
    authority: "DGFT",
    category: "Trade Notice",
    topics: ["foreign-trade"],
    url: "https://www.dgft.gov.in/CP/?opt=trade-notice",
    columns: DGFT_COLUMNS,
    dateFormat: "dd/mm/yyyy",
  },
  {
    id: "gstc-cgst-tax-notification",
    authority: "GST Council",
    category: "CGST Notification",
    topics: ["gst"],
    url: "https://www.gstcouncil.gov.in/cgst-tax-notification",
    columns: { number: 1, pdf: 2, pdfHindi: 3, title: 4 },
  },
  {
    id: "gstc-cgst-rate-notification",
    authority: "GST Council",
    category: "CGST Rate Notification",
    topics: ["gst", "gst-rates"],
    url: "https://www.gstcouncil.gov.in/cgst-rate-notification",
    columns: { number: 0, pdf: 1, pdfHindi: 2, title: 3 },
  },
  {
    id: "gstc-cgst-circular",
    authority: "GST Council",
    category: "CGST Circular",
    topics: ["gst"],
    url: "https://www.gstcouncil.gov.in/cgst-circulars",
    columns: { number: 1, pdf: 2, date: 3, title: 4 },
    dateFormat: "dd-mm-yyyy",
  },
  {
    id: "gstc-press-release",
    authority: "GST Council",
    category: "Press Release",
    topics: ["gst"],
    url: "https://www.gstcouncil.gov.in/press-release",
    columns: { date: 1, title: 2, pdf: 2 },
    dateFormat: "dd-mm-yyyy",
  },
];
