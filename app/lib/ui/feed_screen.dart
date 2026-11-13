import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/tax_update.dart';
import 'update_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _topic;
  Stream<List<TaxUpdate>>? _stream;
  String? _streamTopic = '__none__';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    if (_streamTopic != _topic || _stream == null) {
      _streamTopic = _topic;
      _stream = scope.repo.feed(topic: _topic);
    }
    return ListenableBuilder(
      listenable: scope.settings,
      builder: (context, _) {
        final hi = scope.settings.language == 'hi';
        return Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _chip(hi ? 'सभी' : 'All', null),
                for (final t in Topic.all) _chip(hi ? t.labelHi : t.label, t.id),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaxUpdate>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const _Message('Could not load updates. Check your internet connection.');
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) return const _Message('No updates yet for this topic. The collector checks the official sites every 6 hours.');
                return RefreshIndicator(
                  onRefresh: () => scope.repo.refresh().catchError((_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Could not refresh. Showing the saved copy.')));
                    }
                  }),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: items.length,
                    itemBuilder: (context, i) => UpdateCard(update: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _chip(String label, String? topic) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _topic == topic,
          onSelected: (_) => setState(() => _topic = topic),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));
}
