import 'package:material_ui/material_ui.dart';

import '../app.dart';
import 'common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _key;
  bool _showKey = false;

  static const _official = [
    ('CBIC tax information', 'https://taxinformation.cbic.gov.in/'),
    ('GST Council', 'https://www.gstcouncil.gov.in/'),
    ('GST portal services', 'https://services.gst.gov.in/'),
    ('DGFT', 'https://www.dgft.gov.in/CP/'),
    ('Ministry of Corporate Affairs', 'https://www.mca.gov.in/'),
    ('TaxGuru', 'https://taxguru.in/'),
    ('TaxIndiaOnline', 'https://taxindiaonline.com/'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _key = TextEditingController(text: AppScope.of(context).settings.geminiKey);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _header(context, 'Gemini API key (for the chat)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get a free key at Google AI Studio and paste it here. It stays on this phone.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => openLink(context, 'https://aistudio.google.com/apikey'),
                    child: const Text('Open Google AI Studio'),
                  ),
                  TextField(
                    controller: _key,
                    obscureText: !_showKey,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _showKey ? 'Hide key' : 'Show key',
                        icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showKey = !_showKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await settings.setGeminiKey(_key.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key saved.')));
                      }
                    },
                    child: const Text('Save key'),
                  ),
                ],
              ),
            ),
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
            _header(context, 'Websites'),
            for (final (name, url) in _official)
              ListTile(title: Text(name), trailing: const Icon(Icons.open_in_new), onTap: () => openLink(context, url)),
            _header(context, 'About'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                'Easy-GST is a personal app. Updates come from the official DGFT and GST Council websites every 6 hours. '
                'Summaries and answers are written by Google Gemini and may contain mistakes; always check the official PDF.',
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
