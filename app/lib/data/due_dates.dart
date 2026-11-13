/// Standard GST due dates. These are the usual dates in the GST rules; the
/// government sometimes extends them by notification, which then shows up in
/// the Updates feed. The calendar screen says so.
class DueDate {
  const DueDate({required this.date, required this.form, required this.who, required this.period});
  final DateTime date;
  final String form;
  final String who;
  final String period;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _monthLabel(DateTime m) => '${_months[m.month - 1]} ${m.year}';

String _quarterLabel(DateTime lastMonth) {
  final first = DateTime(lastMonth.year, lastMonth.month - 2);
  return '${_months[first.month - 1]} to ${_monthLabel(lastMonth)}';
}

/// Quarters in India's financial year end in June, September, December and March.
bool _isQuarterEnd(int month) => month % 3 == 0;

/// All standard due dates from [from] (inclusive) for [days] days, soonest first.
List<DueDate> upcomingDueDates(DateTime from, {int days = 60}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = start.add(Duration(days: days));
  final out = <DueDate>[];

  // A return for period month P is due in month P+1. Look at periods from
  // two months back so dates early in this month are included.
  for (var offset = -2; offset <= days ~/ 28 + 1; offset++) {
    final period = DateTime(start.year, start.month + offset);
    final due = DateTime(period.year, period.month + 1);
    DateTime on(int day) => DateTime(due.year, due.month, day);
    final p = _monthLabel(period);

    out.add(DueDate(date: on(11), form: 'GSTR-1', who: 'Monthly filers', period: p));
    out.add(DueDate(date: on(20), form: 'GSTR-3B', who: 'Monthly filers', period: p));

    if (_isQuarterEnd(period.month)) {
      final q = _quarterLabel(period);
      out.add(DueDate(date: on(13), form: 'GSTR-1', who: 'Quarterly filers (QRMP)', period: q));
      out.add(DueDate(date: on(18), form: 'CMP-08', who: 'Composition dealers', period: q));
      out.add(DueDate(date: on(22), form: 'GSTR-3B', who: 'Quarterly filers (QRMP), 22nd or 24th by state', period: q));
    } else {
      out.add(DueDate(date: on(13), form: 'IFF (optional)', who: 'Quarterly filers (QRMP)', period: p));
      out.add(DueDate(date: on(25), form: 'PMT-06 tax payment', who: 'Quarterly filers (QRMP)', period: p));
    }
  }

  for (var y = start.year - 1; y <= end.year; y++) {
    out.add(DueDate(date: DateTime(y, 4, 30), form: 'GSTR-4', who: 'Composition dealers, annual', period: 'FY ${y - 1}-${(y % 100).toString().padLeft(2, '0')}'));
    out.add(DueDate(date: DateTime(y, 12, 31), form: 'GSTR-9', who: 'Annual return', period: 'FY ${y - 1}-${(y % 100).toString().padLeft(2, '0')}'));
  }

  return out.where((d) => !d.date.isBefore(start) && d.date.isBefore(end)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}
