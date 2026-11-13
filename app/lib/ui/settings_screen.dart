import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/tax_update.dart';
import 'common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _official = [
    ('CBIC tax information', 'https://taxinformation.cbic.gov.in/'),
    ('GST Council', 'https://www.gstcouncil.gov.in/'),
    ('GST portal services', 'https://services.gst.gov.in/'),
    ('DGFT', 'https://www.dgft.gov.in/CP/'),
    ('Ministry of Corporate Affairs', 'https://www.mca.gov.in/'),
  ];

  static const _moreReading = [
    ('TaxGuru', 'https://taxguru.in/'),
    ('TaxIndiaOnline', 'https://taxindiaonline.com/'),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _header(context, 'Language for summaries and answers'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'hi', label: Text('हिंदी')),
                ],
                selected: {settings.language},
                onSelectionChanged: (s) => settings.setLanguage(s.first),
              ),
            ),
            _header(context, 'Alerts'),
            for (final t in Topic.all)
              SwitchListTile(
                title: Text(t.label),
                subtitle: Text(t.labelHi),
                value: settings.following.contains(t.id),
                onChanged: (on) async {
                  try {
                    await scope.repo.setFollowing(t.id, on);
                    await settings.setFollowing(t.id, on);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Could not change alerts. Please try again.')));
                    }
                  }
                },
              ),
            _header(context, 'Official sources'),
            for (final (name, url) in _official)
              ListTile(title: Text(name), trailing: const Icon(Icons.open_in_new), onTap: () => openLink(context, url)),
            _header(context, 'More reading on the web'),
            for (final (name, url) in _moreReading)
              ListTile(
                title: Text(name),
                subtitle: const Text('Independent site, opens in your browser'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openLink(context, url),
              ),
            _header(context, 'About'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                '$notAffiliatedText\n\nSummaries and answers are written by Google Gemini and may contain mistakes. They are general information, not tax or legal advice.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
