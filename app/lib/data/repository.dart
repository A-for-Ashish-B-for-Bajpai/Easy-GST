import '../models/tax_update.dart';

/// Everything the screens need. [GithubRepository] is the real one;
/// tests use a fake.
abstract class UpdatesRepository {
  /// Newest first. [topic] null means all topics. Emits the saved copy first
  /// (works offline), then the fresh one.
  Stream<List<TaxUpdate>> feed({String? topic});

  /// Downloads the latest data again.
  Future<void> refresh();

  Future<TaxUpdate?> byId(String id);

  /// Asks Gemini, using the official documents in our library.
  Future<AskResult> ask(String question, {required String language, required String apiKey});
}

class AskException implements Exception {
  AskException(this.message);
  final String message;
  @override
  String toString() => message;
}
