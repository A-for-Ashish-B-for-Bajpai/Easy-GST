import 'package:easy_gst/data/repository.dart';
import 'package:easy_gst/models/tax_update.dart';

/// Fake repository for tests, with real titles from DGFT and the GST Council
/// (taken 2026-11-13).
class DemoRepository implements UpdatesRepository {
  DemoRepository({List<TaxUpdate>? items}) : _items = items ?? sampleUpdates;

  final List<TaxUpdate> _items;
  String? lastKey;
  AskResult? answer;

  @override
  Stream<List<TaxUpdate>> feed({String? topic}) => Stream.value(
        _items.where((u) => topic == null || u.topics.contains(topic)).toList(),
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<TaxUpdate?> byId(String id) async {
    for (final u in _items) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<AskResult> ask(String question, {required String language, required String apiKey}) async {
    lastKey = apiKey;
    if (apiKey.isEmpty) throw AskException('Add your free Gemini API key in Settings to use the chat.');
    return answer ?? const AskResult(answer: 'No answer', confident: false, sources: []);
  }
}

final sampleUpdates = <TaxUpdate>[
  TaxUpdate(
    id: 'demo-dgft-pn-40',
    authority: 'DGFT',
    category: 'Public Notice',
    topics: const ['foreign-trade'],
    number: '40/2026-27',
    title: 'Amendments in Para 2.88 of Handbook of Procedures, 2023 and Appendix 2B of Foreign Trade Policy, 2023-reg.',
    issuedOn: DateTime(2026, 11, 13),
    pdfUrl: 'https://content.dgft.gov.in/Website/dgftprod/768cd243-7a87-4e5b-a78a-691d64512816/PN_0001.pdf',
    listingUrl: 'https://www.dgft.gov.in/CP/?opt=public-notice',
  ),
  TaxUpdate(
    id: 'demo-dgft-n-49',
    authority: 'DGFT',
    category: 'Notification',
    topics: const ['foreign-trade'],
    number: '49/2026-27',
    title: 'Amendment in Export Policy of Waste and Scrap of Primary Cells, Primary Batteries and Electric Accumulators (Lithium-Ion Battery Black Mass) under ITC (HS) 85491400 - regarding.',
    issuedOn: DateTime(2026, 11, 10),
    pdfUrl: 'https://content.dgft.gov.in/Website/dgftprod/58145d8f-19de-4e3a-b7ba-95fdb2ed5ea4/Notification%20No.%2049%20of%202026-2027.pdf',
    listingUrl: 'https://www.dgft.gov.in/CP/?opt=notification',
  ),
  TaxUpdate(
    id: 'demo-gstc-pr-57',
    authority: 'GST Council',
    category: 'Press Release',
    topics: const ['gst'],
    title: 'Press Release Regarding Recommendations of the 57th Meeting of the GST Council',
    issuedOn: DateTime(2026, 10, 8),
    pdfUrl: 'https://www.gstcouncil.gov.in/sites/default/files/2026-10/press_release.pdf',
    listingUrl: 'https://www.gstcouncil.gov.in/press-release',
  ),
  TaxUpdate(
    id: 'demo-gstc-ctr-08',
    authority: 'GST Council',
    category: 'CGST Rate Notification',
    topics: const ['gst', 'gst-rates'],
    number: '08/2025-Central Tax (Rate)',
    title: 'Seeks to amend Notification No 17/2017- Central Tax (Rate), dated 28th June, 2017 to implement the recommendations of the 55th GST Council.',
    pdfUrl: 'https://www.gstcouncil.gov.in/sites/default/files/2025-01/ctr08-2025.pdf',
    pdfUrlHindi: 'https://www.gstcouncil.gov.in/sites/default/files/2025-01/ctr08h-2025.pdf',
    listingUrl: 'https://www.gstcouncil.gov.in/cgst-rate-notification',
  ),
];
