import 'package:material_ui/material_ui.dart';

import 'data/repository.dart';
import 'data/settings_store.dart';
import 'ui/home_shell.dart';

/// Gives every screen the backend and the person's settings.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.repo, required this.settings, required super.child});

  final UpdatesRepository repo;
  final SettingsStore settings;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => repo != old.repo || settings != old.settings;
}

class EasyGstApp extends StatelessWidget {
  const EasyGstApp({super.key, required this.repo, required this.settings});

  final UpdatesRepository repo;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B6E4F);
    return AppScope(
      repo: repo,
      settings: settings,
      child: MaterialApp(
        title: 'Easy-GST',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}
