import 'package:material_ui/material_ui.dart';

import '../app.dart';
import 'ask_screen.dart';
import 'calendar_screen.dart';
import 'common.dart';
import 'feed_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _noticeScheduled = false;

  static const _titles = ['Updates', 'Ask a tax question', 'Due dates', 'Saved'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppScope.of(context).settings;
    if (!settings.seenNotice && !_noticeScheduled) {
      _noticeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
    }
  }

  Future<void> _showNotice() async {
    if (!mounted) return;
    final settings = AppScope.of(context).settings;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Easy-GST'),
        content: const Text('$notAffiliatedText\n\nSummaries and answers are written by Google Gemini and can contain mistakes.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('I understand')),
        ],
      ),
    );
    await settings.markNoticeSeen();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (repo.isPreview) const PreviewBanner(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [FeedScreen(), AskScreen(), CalendarScreen(), SavedScreen()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.feed_outlined), selectedIcon: Icon(Icons.feed), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Ask'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Due dates'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }
}
