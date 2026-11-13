import 'package:material_ui/material_ui.dart';

import '../data/due_dates.dart';
import 'common.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, this.today});

  /// For tests; defaults to now.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today ?? DateTime.now();
    final items = upcomingDueDates(now);
    final todayDate = DateTime(now.year, now.month, now.day);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Standard GST due dates for the next 60 days. The government sometimes extends a date; extensions appear in Updates.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final d in items)
          ListTile(
            leading: CircleAvatar(child: Text('${d.date.day}')),
            title: Text('${d.form}  ·  ${d.period}'),
            subtitle: Text('${d.who}\n${formatDate(d.date)}${d.date == todayDate ? '  ·  Today' : ''}'),
            isThreeLine: true,
          ),
      ],
    );
  }
}
