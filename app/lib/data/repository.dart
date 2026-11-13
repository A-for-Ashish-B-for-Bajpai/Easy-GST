import '../models/tax_update.dart';

/// Everything the screens need from the backend. The Firebase version is used
/// in the real app; tests and the preview mode use [DemoRepository].
abstract class UpdatesRepository {
  /// Newest first. [topic] null means all topics.
  Stream<List<TaxUpdate>> feed({String? topic, int limit = 50});

  Future<TaxUpdate?> byId(String id);

  /// Asks Gemini, through the backend, using our library of official documents.
  Future<AskResult> ask(String question, {required String language});

  /// Lets a user flag a wrong or harmful AI answer or summary.
  Future<void> report({required String kind, required String targetId, String? question, String? answer});

  /// Push alerts for a topic.
  Future<void> setFollowing(String topicId, bool follow);

  bool get isPreview;
}

class AskException implements Exception {
  AskException(this.message);
  final String message;
  @override
  String toString() => message;
}
