# Easy-GST

Easy GST is a user-friendly app to learn everything about Goods and Services Tax. It explains GST rates, registration, invoices, returns, ITC, and updates in simple language. Its key objective is to provide educational and learning support for students, businesses, and taxpayers. For official filings, use the GST portal or a tax professional.

A free Android and iPhone app that collects official GST and foreign trade updates into one feed and uses Google Gemini to explain them in plain English and Hindi.

> Easy-GST is independent. It is not made by, or connected to, the Government of India, CBIC, the GST Council, GSTN, DGFT or MCA. Every update links to its official source.

## What's here

| Folder | What it is |
| --- | --- |
| `app/` | Flutter app (Android and iOS): updates feed, plain-language detail page, "Ask a tax question" chat, GST due dates, saved items, alerts |
| `functions/` | Firebase Cloud Functions (TypeScript): collectors for the government sites, Gemini summaries and translation, the chat backend |
| `firestore.rules`, `firestore.indexes.json` | Database security rules and indexes, including the vector index used by the chat |

## How it works

1. `collectUpdates` runs every 6 hours (India time) in Mumbai (`asia-south1`). It reads the listing pages of each source, and stores documents it hasn't seen in Firestore `updates/`.
2. `summariseNewUpdate` runs for each new document. It downloads the PDF and asks Gemini for a plain title, a 3 to 5 line summary in English and Hindi, who it affects, and the key facts. Gemini reads the PDF itself, so scanned PDFs (common on DGFT) work. It then stores a search embedding and sends one push alert to people following that topic.
3. `askTaxQuestion` answers questions in the app. It finds the closest official documents with Firestore vector search, and has Gemini answer only from them, with sources. It needs App Check and a signed-in (anonymous) user, and allows 20 questions per person per day.

Gemini is called through Vertex AI with the functions' service account, so no API key is stored anywhere or shipped in the app.

## Sources

| Source | Lists | Status |
| --- | --- | --- |
| DGFT | Notifications, Public Notices, Circulars, Trade Notices | Working, tested live 2026-11-13 |
| GST Council | CGST notifications, CGST rate notifications, CGST circulars, press releases | Working, tested live 2026-11-13 |
| CBIC tax information | | Not yet: resets connections from non-Indian servers. To retry from the Mumbai region |
| MCA | | Not yet: returns 403 to automated requests |
| GST portal (GSTIN, HSN lookup) | | Version 2, needs a paid GST Suvidha Provider API |
| TaxGuru, TaxIndiaOnline | | Linked only. Their terms don't allow copying their content |

Column positions for each list are in `functions/src/sources.ts`. If a site changes its layout, the parser tests fail and the `sources/{id}` health record shows `lastError`.

## Set up (one time)

You need: a Google account, Node 22, the Flutter SDK, and the Firebase CLI (`npm install -g firebase-tools`).

1. **Create a Firebase project** at https://console.firebase.google.com and upgrade it to the Blaze (pay as you go) plan. Scheduled functions and Gemini need it; costs at small scale are low.
2. In the Google Cloud console for that project, **enable the Vertex AI API**.
3. In Firebase: turn on **Firestore** (location `asia-south1`), **Authentication → Anonymous**, **Cloud Messaging**, and **App Check** (Play Integrity for Android, App Attest for iOS).
4. Put your project id in `.firebaserc`, then from the repo root:
   ```sh
   cd functions && npm install && npm test && cd ..
   firebase deploy --only firestore,functions
   ```
5. **Connect the app** to Firebase:
   ```sh
   cd app
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-project-id>
   ```
   Then open the generated `lib/firebase_options.dart` and add `static const bool isConfigured = true;` inside `DefaultFirebaseOptions`.
6. Run it: `flutter run`.

Until step 5 is done the app runs in **preview mode** with a few real sample updates and the chat turned off, so the screens can be tried.

## Check the collectors without Firebase

```sh
cd functions
npm install
npm run collect:dry
```

This fetches every source live and prints what it found. Behind a proxy, add `NODE_USE_ENV_PROXY=1`.

## Tests

```sh
cd functions && npm test     # parsers (on saved copies of the real pages) and backend logic
cd app && flutter test       # due dates, data model, screens
```

## Changing the Gemini model

Set `GEMINI_MODEL` (default `gemini-3.8-flash`) or `EMBEDDING_MODEL` (default `gemini-embedding-001`) in `functions/.env` and redeploy. Changing the embedding model means re-embedding stored documents.
