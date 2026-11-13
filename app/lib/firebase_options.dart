// Placeholder. Replace this file by running, from the app folder:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project-id>
//
// That writes the real options for Android and iOS. Then set
// `isConfigured` to true in the generated file (add the getter below).

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Run `flutterfire configure` to connect Firebase.');
}
