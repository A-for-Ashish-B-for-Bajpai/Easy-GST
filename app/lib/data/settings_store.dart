import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Things a person sets on their own phone: language, saved updates, topics
/// they follow, and whether they have seen the first-run notice.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  static Future<SettingsStore> load() async => SettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  String get language => _prefs.getString('language') ?? 'en';
  Future<void> setLanguage(String value) async {
    await _prefs.setString('language', value);
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

  Set<String> get following => (_prefs.getStringList('following') ?? const []).toSet();
  Future<void> setFollowing(String topicId, bool follow) async {
    final s = following;
    follow ? s.add(topicId) : s.remove(topicId);
    await _prefs.setStringList('following', s.toList());
    notifyListeners();
  }

  bool get seenNotice => _prefs.getBool('seenNotice') ?? false;
  Future<void> markNoticeSeen() async {
    await _prefs.setBool('seenNotice', true);
    notifyListeners();
  }
}
