import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Things kept on your phone: language, saved updates, your Gemini key, and
/// when you last opened the app (for the "New" labels).
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) : previousVisit = _readDate(_prefs.getString('lastVisit'));

  static Future<SettingsStore> load() async => SettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// The day the app was last opened before today's session. Null on first use.
  final DateTime? previousVisit;

  static DateTime? _readDate(String? s) => s == null ? null : DateTime.tryParse(s);

  /// Call once at start-up.
  Future<void> recordVisit(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    await _prefs.setString('lastVisit', today.toIso8601String().substring(0, 10));
  }

  /// True for updates first collected after your previous visit.
  bool isNew(DateTime? firstSeenOn) => previousVisit != null && firstSeenOn != null && firstSeenOn.isAfter(previousVisit!);

  String get language => _prefs.getString('language') ?? 'en';
  Future<void> setLanguage(String value) async {
    await _prefs.setString('language', value);
    notifyListeners();
  }

  /// Your own free key from Google AI Studio, used only for the chat.
  String get geminiKey => _prefs.getString('geminiKey') ?? '';
  Future<void> setGeminiKey(String value) async {
    await _prefs.setString('geminiKey', value.trim());
    notifyListeners();
  }

  Set<String> get saved => (_prefs.getStringList('saved') ?? const []).toSet();
  bool isSaved(String id) => saved.contains(id);
  Future<void> toggleSaved(String id) async {
    final s = saved;
    s.contains(id) ? s.remove(id) : s.add(id);
    await _prefs.setStringList('saved', s.toList());
    notifyListeners();
  }
}
