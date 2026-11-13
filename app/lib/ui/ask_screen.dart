import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/repository.dart';
import '../models/tax_update.dart';
import 'common.dart';

class _Turn {
  _Turn(this.question);
  final String question;
  AskResult? result;
  String? error;
}

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _busy = false;

  static const _examples = [
    'What is the due date for GSTR-3B?',
    'What did the latest GST Council meeting decide?',
    'Has the export policy for rice changed?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _controller.text).trim();
    if (question.length < 3 || _busy) return;
    final scope = AppScope.of(context);
    final turn = _Turn(question);
    setState(() {
      _turns.add(turn);
      _busy = true;
      _controller.clear();
    });
    try {
      turn.result = await scope.repo.ask(question, language: scope.settings.language, apiKey: scope.settings.geminiKey);
    } on AskException catch (e) {
      turn.error = e.message;
    } catch (_) {
      turn.error = 'Something went wrong. Please check your internet connection and try again.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _turns.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Ask about GST, customs or import and export rules.', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Answers come from official notifications in our library, with links to the source.',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    for (final q in _examples)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ActionChip(label: Text(q), onPressed: () => _send(q)),
                      ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _turns.length,
                  itemBuilder: (context, i) => _TurnView(turn: _turns[i]),
                ),
        ),
        if (_busy) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type your question',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});
  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = turn.result;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(turn.question, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 8),
          if (turn.error != null)
            Text(turn.error!, style: TextStyle(color: theme.colorScheme.error))
          else if (result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!result.confident)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Not sure: our documents may not fully cover this.',
                            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.tertiary)),
                      ),
                    SelectableText(result.answer, style: theme.textTheme.bodyLarge),
                    if (result.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Sources', style: theme.textTheme.titleSmall),
                      for (final s in result.sources)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(s.title),
                          subtitle: Text([s.authority, if (s.number != null) s.number!].join(' · ')),
                          onTap: () => openLink(context, s.pdfUrl),
                        ),
                    ],
                    const SizedBox(height: 8),
                    const AiNotice(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
