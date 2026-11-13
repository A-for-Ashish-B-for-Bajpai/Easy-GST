import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/tax_update.dart';
import 'common.dart';

class UpdateDetailScreen extends StatelessWidget {
  const UpdateDetailScreen({super.key, required this.update});
  final TaxUpdate update;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final lang = settings.language;
        final summary = update.summary(lang);
        final saved = settings.isSaved(update.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(update.category),
            actions: [
              IconButton(
                tooltip: saved ? 'Remove from saved' : 'Save',
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => settings.toggleSaved(update.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(update.displayTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                [
                  update.authority,
                  if (update.number != null) 'No. ${update.number}',
                  if (update.issuedOn != null) formatDate(update.issuedOn!),
                ].join(' · '),
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              if (update.hasSummary) ...[
                Row(
                  children: [
                    Text('In simple words', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'hi', label: Text('हिंदी')),
                      ],
                      selected: {lang},
                      onSelectionChanged: (s) => settings.setLanguage(s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in summary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('•  '), Expanded(child: Text(line, style: theme.textTheme.bodyLarge))],
                    ),
                  ),
                if (update.whoIsAffected?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text('Who this affects', style: theme.textTheme.titleSmall),
                  Text(update.whoIsAffected!, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 12),
                const AiNotice(),
              ] else
                Text('A plain-language summary is not ready yet. Please read the official document below.',
                    style: theme.textTheme.bodyLarge),
              const Divider(height: 32),
              // Without a plain title, the heading above already is the official title.
              if (update.hasSummary) ...[
                Text('Official title', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(update.title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: () => openLink(context, update.pdfUrl),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Open official PDF'),
              ),
              if (update.pdfUrlHindi != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openLink(context, update.pdfUrlHindi!),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('हिंदी PDF खोलें'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openLink(context, update.listingUrl),
                child: Text('See it on the ${update.authority} website'),
              ),
            ],
          ),
        );
      },
    );
  }
}
