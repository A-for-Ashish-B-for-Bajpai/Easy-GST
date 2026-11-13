import 'package:easy_gst/models/tax_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap reads backend fields and falls back to the official title', () {
    final u = TaxUpdate.fromMap('abc', {
      'authority': 'DGFT',
      'category': 'Notification',
      'topics': ['foreign-trade'],
      'number': '47',
      'title': 'Amendment in Export Policy Condition under HSN 1006',
      'issuedOn': '2026-11-09',
      'pdfUrl': 'https://example.gov.in/a.pdf',
      'listingUrl': 'https://example.gov.in/',
    });
    expect(u.issuedOn, DateTime(2026, 11, 9));
    expect(u.hasSummary, isFalse);
    expect(u.displayTitle, startsWith('Amendment'));
  });

  test('summary uses Hindi when chosen and available', () {
    final u = TaxUpdate.fromMap('x', {
      'title': 't',
      'plainTitle': 'Rice export rule changed',
      'summaryEn': ['English line'],
      'summaryHi': ['हिंदी पंक्ति'],
    });
    expect(u.displayTitle, 'Rice export rule changed');
    expect(u.summary('hi'), ['हिंदी पंक्ति']);
    expect(u.summary('en'), ['English line']);
    expect(TaxUpdate.fromMap('y', {'title': 't', 'summaryEn': ['e']}).summary('hi'), ['e']);
  });
}
