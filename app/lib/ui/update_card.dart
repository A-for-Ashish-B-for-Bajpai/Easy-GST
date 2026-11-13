import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/tax_update.dart';
import 'common.dart';
import 'update_detail_screen.dart';

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.update});
  final TaxUpdate update;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    final summary = update.summary(settings.language);
    final meta = [
      update.authority,
      update.category,
      if (update.issuedOn != null) formatDate(update.issuedOn!),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateDetailScreen(update: update))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 6),
              Text(update.displayTitle, style: theme.textTheme.titleMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(summary.first, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
