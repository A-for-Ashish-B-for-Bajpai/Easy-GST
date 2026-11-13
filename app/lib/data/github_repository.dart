import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/tax_update.dart';
import 'gemini_client.dart';
import 'repository.dart';

/// Reads the JSON files the collector publishes on the repository's `data`
/// branch (free hosting from GitHub), and keeps a copy on the phone so the
/// app works offline.
class GithubRepository implements UpdatesRepository {
  GithubRepository({required this.baseUrl, http.Client? client, GeminiClient? gemini, Future<Directory> Function()? cacheDir})
      : _http = client ?? http.Client(),
        _gemini = gemini ?? GeminiClient(client: client),
        _cacheDir = cacheDir ?? getApplicationSupportDirectory;

  /// Default: the public data branch of the Easy-GST repository.
  static const defaultBaseUrl = 'https://raw.githubusercontent.com/A-for-Ashish-B-for-Bajpai/easy-gst/data';

  final String baseUrl;
  final http.Client _http;
  final GeminiClient _gemini;
  final Future<Directory> Function() _cacheDir;

  final _updates = StreamController<List<TaxUpdate>>.broadcast();
  List<TaxUpdate>? _latest;
  Object? _lastError;
  List<_ChatEntry>? _chat;

  static const _contextDocs = 6;

  /// The saved copy, or null when this platform has no app folder (web) or nothing is saved.
  Future<File?> _cacheFile(String name) async {
    try {
      return File('${(await _cacheDir()).path}/$name');
    } catch (_) {
      return null;
    }
  }

  /// Fetches a data file, saving it for offline use; falls back to the saved copy.
  Future<String?> _load(String name, {bool preferCache = false}) async {
    final file = await _cacheFile(name);
    if (preferCache && file != null && await file.exists()) return file.readAsString();
    try {
      final res = await _http.get(Uri.parse('$baseUrl/$name')).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      if (file != null) {
        try {
          await file.parent.create(recursive: true);
          await file.writeAsString(body);
        } catch (_) {/* saving is best effort */}
      }
      return body;
    } catch (_) {
      if (file != null && await file.exists()) return file.readAsString();
      rethrow;
    }
  }

  static List<TaxUpdate> parseUpdates(String json) {
    final list = (jsonDecode(json) as Map<String, dynamic>)['updates'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().map((m) => TaxUpdate.fromMap(m['id'] as String? ?? '', m)).toList();
  }

  void _emit(List<TaxUpdate> items) {
    _latest = items;
    _lastError = null;
    _updates.add(items);
  }

  bool _started = false;
  void _start() {
    if (_started) return;
    _started = true;
    () async {
      try {
        final cached = await _load('updates.json', preferCache: true);
        if (cached != null) _emit(parseUpdates(cached));
      } catch (_) {/* nothing saved yet */}
      await refresh().catchError((_) {});
    }();
  }

  @override
  Future<void> refresh() async {
    try {
      final body = await _load('updates.json');
      if (body != null) _emit(parseUpdates(body));
      _chat = null; // reload the chat index next time it's needed
    } catch (e) {
      _lastError = e;
      if (_latest == null) _updates.addError(e);
      rethrow;
    }
  }

  @override
  Stream<List<TaxUpdate>> feed({String? topic}) {
    _start();
    List<TaxUpdate> filter(List<TaxUpdate> all) => topic == null ? all : all.where((u) => u.topics.contains(topic)).toList();
    return Stream.multi((controller) {
      if (_latest != null) controller.add(filter(_latest!));
      if (_latest == null && _lastError != null) controller.addError(_lastError!);
      final sub = _updates.stream.listen((items) => controller.add(filter(items)), onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<TaxUpdate?> byId(String id) async {
    if (_latest == null) {
      try {
        final cached = await _load('updates.json', preferCache: true);
        if (cached != null) _latest = parseUpdates(cached);
      } catch (_) {
        return null;
      }
    }
    for (final u in _latest ?? const <TaxUpdate>[]) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<List<_ChatEntry>> _chatIndex() async {
    if (_chat != null) return _chat!;
    final body = await _load('chat-index.json');
    final entries = (jsonDecode(body!) as Map<String, dynamic>)['entries'] as List? ?? const [];
    return _chat = entries.whereType<Map<String, dynamic>>().map(_ChatEntry.fromMap).toList();
  }

  static const _system = '''You are Easy-GST, a helper that explains Indian GST, customs and foreign trade rules in simple language.
Rules:
- Answer ONLY from the official documents provided. If they do not cover the question, say you are not sure
  and suggest checking the official website or a tax professional. Set confident=false in that case.
- Only answer questions about Indian tax, GST, customs, foreign trade or company law. Politely decline anything else.
- Give general information, not personal tax or legal advice.
- Keep answers under 150 words. Mention document numbers you relied on.
- List the ids of the documents you actually used in usedSourceIds.
- Write the answer in the language requested.''';

  static const _schema = {
    'type': 'object',
    'properties': {
      'answer': {'type': 'string'},
      'usedSourceIds': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'confident': {'type': 'boolean'},
    },
    'required': ['answer', 'usedSourceIds', 'confident'],
  };

  @override
  Future<AskResult> ask(String question, {required String language, required String apiKey}) async {
    if (apiKey.trim().isEmpty) {
      throw AskException('Add your free Gemini API key in Settings to use the chat.');
    }
    final List<_ChatEntry> index;
    try {
      index = await _chatIndex();
    } catch (_) {
      throw AskException('Could not load the document library. Check your internet connection.');
    }
    if (index.isEmpty) {
      throw AskException('No documents have been summarised yet. The collector adds them every 6 hours.');
    }

    final query = await _gemini.embedQuery(question, apiKey.trim());
    final ranked = [...index]..sort((a, b) => dot(query, b.vector).compareTo(dot(query, a.vector)));
    final top = ranked.take(_contextDocs).toList();

    final docs = top.map((c) => '<document id="${c.id}">\n${c.text}\n</document>').join('\n\n');
    final res = await _gemini.generateJson(
      apiKey: apiKey.trim(),
      system: _system,
      schema: _schema,
      prompt: 'Official documents:\n$docs\n\nLanguage: ${language == 'hi' ? 'Hindi' : 'English'}\n\nQuestion: $question',
    );

    final used = ((res['usedSourceIds'] as List?) ?? const []).whereType<String>().toSet();
    final sources = <AskSource>[];
    for (final c in top.where((c) => used.contains(c.id))) {
      final u = await byId(c.id);
      if (u != null) sources.add(AskSource.fromUpdate(u));
    }
    return AskResult(answer: (res['answer'] as String? ?? '').trim(), confident: res['confident'] == true, sources: sources);
  }
}

class _ChatEntry {
  _ChatEntry(this.id, this.vector, this.text);
  final String id;
  final List<double> vector;
  final String text;

  factory _ChatEntry.fromMap(Map<String, dynamic> m) => _ChatEntry(
        m['id'] as String? ?? '',
        ((m['e'] as List?) ?? const []).map((v) => (v as num).toDouble()).toList(),
        m['t'] as String? ?? '',
      );
}
