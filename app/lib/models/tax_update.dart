import 'package:cloud_firestore/cloud_firestore.dart';

/// One official notification, circular or notice, with Gemini's plain summary
/// when it is ready. Mirrors `updates/{id}` written by the backend.
class TaxUpdate {
  const TaxUpdate({
    required this.id,
    required this.authority,
    required this.category,
    required this.topics,
    required this.title,
    required this.pdfUrl,
    required this.listingUrl,
    this.number,
    this.issuedOn,
    this.sortDate,
    this.pdfUrlHindi,
    this.plainTitle,
    this.summaryEn = const [],
    this.summaryHi = const [],
    this.whoIsAffected,
  });

  final String id;
  final String authority;
  final String category;
  final List<String> topics;
  final String? number;
  final String title;
  final DateTime? issuedOn;
  final DateTime? sortDate;
  final String pdfUrl;
  final String? pdfUrlHindi;
  final String listingUrl;
  final String? plainTitle;
  final List<String> summaryEn;
  final List<String> summaryHi;
  final String? whoIsAffected;

  bool get hasSummary => summaryEn.isNotEmpty;

  /// The plain title when Gemini has written one, otherwise the official title.
  String get displayTitle =>
      (plainTitle != null && plainTitle!.isNotEmpty) ? plainTitle! : title;

  List<String> summary(String language) =>
      language == 'hi' && summaryHi.isNotEmpty ? summaryHi : summaryEn;

  static DateTime? _date(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  static List<String> _strings(Object? v) =>
      v is List ? v.whereType<String>().toList() : const [];

  factory TaxUpdate.fromMap(String id, Map<String, dynamic> d) => TaxUpdate(
        id: id,
        authority: d['authority'] as String? ?? '',
        category: d['category'] as String? ?? '',
        topics: _strings(d['topics']),
        number: d['number'] as String?,
        title: d['title'] as String? ?? '',
        issuedOn: _date(d['issuedOn']),
        sortDate: _date(d['sortDate']),
        pdfUrl: d['pdfUrl'] as String? ?? '',
        pdfUrlHindi: d['pdfUrlHindi'] as String?,
        listingUrl: d['listingUrl'] as String? ?? '',
        plainTitle: d['plainTitle'] as String?,
        summaryEn: _strings(d['summaryEn']),
        summaryHi: _strings(d['summaryHi']),
        whoIsAffected: d['whoIsAffected'] as String?,
      );

  factory TaxUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      TaxUpdate.fromMap(doc.id, doc.data() ?? const {});
}

/// Topics people can follow. Ids match the backend and FCM topics `topic-<id>`.
class Topic {
  const Topic(this.id, this.label, this.labelHi);
  final String id;
  final String label;
  final String labelHi;

  static const all = [
    Topic('gst', 'GST', 'जीएसटी'),
    Topic('gst-rates', 'GST rates', 'जीएसटी दरें'),
    Topic('foreign-trade', 'Import and export', 'आयात-निर्यात'),
  ];
}

class AskSource {
  const AskSource({required this.id, required this.title, required this.authority, required this.pdfUrl, this.number});
  final String id;
  final String title;
  final String authority;
  final String pdfUrl;
  final String? number;

  factory AskSource.fromMap(Map<Object?, Object?> m) => AskSource(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        authority: m['authority'] as String? ?? '',
        pdfUrl: m['pdfUrl'] as String? ?? '',
        number: m['number'] as String?,
      );
}

class AskResult {
  const AskResult({required this.answer, required this.confident, required this.sources, this.remainingToday});
  final String answer;
  final bool confident;
  final List<AskSource> sources;
  final int? remainingToday;
}
