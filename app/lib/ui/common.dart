import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final _dateFormat = DateFormat('d MMM yyyy');
String formatDate(DateTime d) => _dateFormat.format(d);

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }
}

/// Shown under every AI summary and answer.
class AiNotice extends StatelessWidget {
  const AiNotice({super.key, this.onReport});
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome, size: 16, color: style?.color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Written by Google Gemini from the official document. It is general information, not tax advice. Always check the official PDF.',
            style: style,
          ),
        ),
        if (onReport != null)
          TextButton(onPressed: onReport, child: const Text('Report')),
      ],
    );
  }
}

const notAffiliatedText =
    'Easy-GST is an independent app. It is not made by, or connected to, the Government of India, CBIC, the GST Council, GSTN, DGFT or MCA. '
    'Every update links to its official source on the government website.';

class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Preview mode: sample updates only. Connect Firebase to get live updates and Gemini.',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}
