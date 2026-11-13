import 'package:easy_gst/data/due_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mid-November shows November monthly returns for October', () {
    final items = upcomingDueDates(DateTime(2026, 11, 13), days: 30);
    final gstr3b = items.firstWhere((d) => d.form == 'GSTR-3B' && d.who == 'Monthly filers');
    expect(gstr3b.date, DateTime(2026, 11, 20));
    expect(gstr3b.period, 'Oct 2026');
    // GSTR-1 on the 11th has already passed.
    expect(items.any((d) => d.date == DateTime(2026, 11, 11)), isFalse);
    // October is not a quarter end, so QRMP filers pay by PMT-06 on the 25th.
    expect(items.any((d) => d.form == 'PMT-06 tax payment' && d.date == DateTime(2026, 11, 25)), isTrue);
  });

  test('quarter-end returns fall in the month after the quarter', () {
    final items = upcomingDueDates(DateTime(2027, 1, 1), days: 31);
    final cmp = items.firstWhere((d) => d.form == 'CMP-08');
    expect(cmp.date, DateTime(2027, 1, 18));
    expect(cmp.period, 'Oct to Dec 2026');
    expect(items.where((d) => d.form == 'GSTR-1' && d.who.startsWith('Quarterly')).single.date, DateTime(2027, 1, 13));
  });

  test('annual return on 31 December is included and list is sorted', () {
    final items = upcomingDueDates(DateTime(2026, 12, 1), days: 40);
    expect(items.any((d) => d.form == 'GSTR-9' && d.date == DateTime(2026, 12, 31)), isTrue);
    for (var i = 1; i < items.length; i++) {
      expect(items[i].date.isBefore(items[i - 1].date), isFalse);
    }
  });
}
