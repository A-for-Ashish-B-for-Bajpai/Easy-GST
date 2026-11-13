import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/demo_repository.dart';
import 'data/firebase_repository.dart';
import 'data/repository.dart';
import 'data/settings_store.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(EasyGstApp(repo: await _connect(), settings: settings));
}

/// Connects to Firebase. Until `flutterfire configure` has been run, the app
/// starts in preview mode with sample data instead of crashing.
Future<UpdatesRepository> _connect() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint('Firebase is not configured yet; starting in preview mode.');
    return DemoRepository();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
  );
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  return FirebaseRepository();
}
