import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/github_repository.dart';
import 'data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  await settings.recordVisit(DateTime.now());
  runApp(EasyGstApp(
    // Override with --dart-define=DATA_URL=... to read data from somewhere else.
    repo: GithubRepository(baseUrl: const String.fromEnvironment('DATA_URL', defaultValue: GithubRepository.defaultBaseUrl)),
    settings: settings,
  ));
}
