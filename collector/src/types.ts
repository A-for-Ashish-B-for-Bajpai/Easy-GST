/** Where an update came from. Matches the `id` of a SourceConfig. */
export type Authority = "DGFT" | "GST Council" | "CBIC" | "MCA";

/** Topics users can follow. Each maps to an FCM topic `topic-<id>`. */
export type Topic = "gst" | "gst-rates" | "foreign-trade" | "customs" | "company-law";

export interface SourceConfig {
  /** Stable id, used in Firestore and logs, e.g. "dgft-notification". */
  id: string;
  authority: Authority;
  /** Human label shown in the app, e.g. "Public Notice". */
  category: string;
  topics: Topic[];
  /** Listing page that holds a table of documents, newest first. */
  url: string;
  /** Zero-based <td> positions in each table row. */
  columns: {
    number?: number;
    title: number;
    date?: number;
    /** Cell holding the English PDF link. If omitted, the first .pdf link in the row is used. */
    pdf?: number;
    /** Cell holding the Hindi PDF link, when the site publishes one. */
    pdfHindi?: number;
  };
  /** How the date cell is written. */
  dateFormat?: "dd/mm/yyyy" | "dd-mm-yyyy";
}

/** One notification, circular or notice, as stored in Firestore `updates/{id}`. */
export interface Update {
  id: string;
  sourceId: string;
  authority: Authority;
  category: string;
  topics: Topic[];
  number: string | null;
  title: string;
  /** ISO date (yyyy-mm-dd) when the site gives one. */
  issuedOn: string | null;
  pdfUrl: string;
  pdfUrlHindi: string | null;
  listingUrl: string;
}

/** Fields Gemini adds after the update is stored. */
export interface Summary {
  /** 3 to 5 short plain-English lines. */
  summaryEn: string[];
  /** The same in Hindi. */
  summaryHi: string[];
  /** Who this affects, in one plain sentence. */
  whoIsAffected: string;
  /** A short plain title, since official titles are often long. */
  plainTitle: string;
  /**
   * Up to about 250 words of the document's concrete facts (codes, rates, dates,
   * forms). Used for the chat when the PDF is scanned and has no text layer.
   */
  keyFacts: string;
}
