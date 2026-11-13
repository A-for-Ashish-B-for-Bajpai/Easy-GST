# Easy-GST

Easy GST is a user-friendly app to learn everything about Goods and Services Tax. It explains GST rates, registration, invoices, returns, ITC, and updates in simple language. Its key objective is to provide educational and learning support for students, businesses, and taxpayers. For official filings, use the GST portal or a tax professional.

This version is a **personal app**: it collects official GST and foreign trade updates into one feed for your own phone, and uses Google Gemini to explain them in plain English and Hindi. **It costs nothing to run**: it uses only free services (GitHub Actions, GitHub file hosting and the Gemini API free tier), with no server, no database and no card on file.

## How it works

```
Government sites ──► GitHub Actions (every 6 hours, free) ──► data branch (JSON, free hosting) ──► app on your phone
                         │  reads new notifications                                              │
                         └─ Gemini free tier: summary in English + Hindi                         └─ chat: your own free Gemini key
```

1. `.github/workflows/collect.yml` runs every 6 hours. It reads the listing pages of each source and adds documents it hasn't seen.
2. For new documents it asks Gemini (free tier) for a plain title, a 3 to 5 line summary in English and Hindi, who it affects and the key facts. Gemini reads the PDF itself, so scanned PDFs (common on DGFT) work. At most 12 documents are summarised per run so it stays inside the free limits; the rest wait for the next run.
3. Results are committed to the `data` branch as `updates.json` (the feed), `chat-index.json` (for the chat) and `sources.json` (health of each site).
4. The app downloads those files from GitHub and keeps a copy for offline reading.
5. **Ask a tax question** runs on your phone: it finds the closest official documents in `chat-index.json` and asks Gemini to answer only from them, with sources. It uses a free Gemini key you paste into Settings.

## Sources

| Source | Lists | Status |
| --- | --- | --- |
| DGFT | Notifications, Public Notices, Circulars, Trade Notices | Working, tested live 2026-11-13 |
| GST Council | CGST notifications, CGST rate notifications, CGST circulars, press releases | Working, tested live 2026-11-13 |
| CBIC tax information | | Not yet: resets connections from non-Indian servers, including GitHub's |
| MCA | | Not yet: returns 403 to automated requests |
| GST portal (GSTIN, HSN lookup) | | Not included: needs a paid GST Suvidha Provider API |
| TaxGuru, TaxIndiaOnline | | Linked from Settings only. Their terms don't allow copying their content |

Column positions for each list are in `collector/src/sources.ts`. If a site changes its layout, the parser tests fail and `sources.json` shows `lastError`.

## Set up (one time, free)

1. **Get a free Gemini API key** at https://aistudio.google.com/apikey (sign in with your Google account; no card needed).
2. **Give the collector the key**: in this repository on GitHub, open Settings → Secrets and variables → Actions → New repository secret. Name `GEMINI_API_KEY`, value your key.
3. **Run the collector once**: Actions tab → "Collect updates" → Run workflow. It creates the `data` branch. After that it runs by itself every 6 hours. The first few runs summarise the newest documents; older ones stay unsummarised to save quota.
4. **Get the app on your Android phone**: Actions tab → "Build Android app" → Run workflow. When it finishes, download `easy-gst-apk` from the run page, unzip it, copy `app-release.apk` to your phone and open it (allow "install unknown apps" when asked).
5. In the app, open **Settings** and paste the same Gemini key to use the chat.

**iPhone**: installing your own app on an iPhone for free needs a Mac with Xcode (`cd app && flutter run` with your phone connected, signed with a free Apple ID). Apps installed this way stop opening after 7 days and need reinstalling. Publishing properly needs the paid Apple Developer Program, so it's left out for now.

### Good to know about the free tier

- **Limits**: the Gemini free tier allows a limited number of requests per minute and per day (see your limits at https://aistudio.google.com/rate-limit). If the collector hits them, it stops and continues next run. If the chat hits them, it says so; try again later.
- **Privacy**: on the free tier Google may use what you send to improve its products. The documents are public, but don't type personal details into the chat.
- **Scheduled runs pause after 60 days without activity** in the repository. If that happens, GitHub emails you; re-enable it from the Actions tab.
- To use a different model (for example one with a higher free limit), set a repository variable `GEMINI_MODEL` under Settings → Secrets and variables → Actions → Variables.

## Folders

| Folder | What it is |
| --- | --- |
| `app/` | Flutter app: updates feed with "New" labels, plain-language detail page, chat, GST due dates, saved items, settings |
| `collector/` | Node/TypeScript collector run by GitHub Actions: site parsers, Gemini summaries, data files |
| `.github/workflows/` | `collect.yml` (every 6 hours), `build-apk.yml` (Android app), `test.yml` (tests on every change) |

## Develop

```sh
cd collector && npm install && npm test   # parsers (on saved copies of the real pages) and pipeline
npm run collect:dry                        # fetch every source live and print what it finds
cd ../app && flutter test                  # due dates, data loading, chat, screens
```
