import 'dart:convert';
import 'dart:io';

import 'package:easy_gst/data/gemini_client.dart';
import 'package:easy_gst/data/github_repository.dart';
import 'package:easy_gst/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _updates = {
  'generatedAt': '2026-11-13T12:00:00Z',
  'updates': [
    {'id': 'u1', 'authority': 'DGFT', 'category': 'Circular', 'topics': ['foreign-trade'], 'number': '02/2026-27', 'title': 'Silver import', 'plainTitle': 'Silver import rule clarified', 'summaryEn': ['a'], 'pdfUrl': 'https://x/u1.pdf', 'listingUrl': 'https://x', 'firstSeenOn': '2026-11-13'},
    {'id': 'u2', 'authority': 'GST Council', 'category': 'Press Release', 'topics': ['gst'], 'title': '57th meeting', 'pdfUrl': 'https://x/u2.pdf', 'listingUrl': 'https://x'},
  ],
};

const _chat = {
  'entries': [
    {'id': 'u1', 'e': [1.0, 0.0], 't': 'DGFT Circular 02/2026-27 silver'},
    {'id': 'u2', 'e': [0.0, 1.0], 't': 'GST Council 57th meeting'},
  ],
};

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('easygst'));
  tearDown(() => dir.deleteSync(recursive: true));

  GithubRepository repo(http.Client client) =>
      GithubRepository(baseUrl: 'https://data.test', client: client, cacheDir: () async => dir);

  test('feed downloads updates, filters by topic, and works offline after', () async {
    final online = MockClient((req) async => http.Response(jsonEncode(_updates), 200));
    final first = await repo(online).feed(topic: 'gst').firstWhere((l) => l.isNotEmpty);
    expect(first.single.id, 'u2');

    final offline = MockClient((req) async => throw const SocketException('offline'));
    final cached = await repo(offline).feed().first;
    expect(cached.map((u) => u.id), ['u1', 'u2']);
    expect(cached.first.firstSeenOn, DateTime(2026, 11, 13));
  });

  test('ask picks the closest documents and returns only the sources Gemini used', () async {
    late Map<String, dynamic> generateBody;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('updates.json')) return http.Response(jsonEncode(_updates), 200);
      if (path.endsWith('chat-index.json')) return http.Response(jsonEncode(_chat), 200);
      expect(req.headers['x-goog-api-key'], 'k');
      if (path.endsWith(':embedContent')) {
        expect(jsonDecode(req.body)['outputDimensionality'], GeminiClient.dimensions);
        return http.Response(jsonEncode({'embedding': {'values': [0.0, 5.0]}}), 200);
      }
      generateBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': jsonEncode({'answer': 'It removed arrest provisions.', 'usedSourceIds': ['u2', 'made-up'], 'confident': true})}]}}
            ]
          }),
          200);
    });

    final result = await repo(client).ask('What did the 57th meeting decide?', language: 'en', apiKey: ' k ');
    expect(result.answer, 'It removed arrest provisions.');
    expect(result.sources.map((s) => s.id), ['u2']);
    // The closest document comes first in the prompt.
    final prompt = generateBody['contents'][0]['parts'][0]['text'] as String;
    expect(prompt.indexOf('id="u2"'), lessThan(prompt.indexOf('id="u1"')));
  });

  test('ask explains a missing key, a bad key and the free limit', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('chat-index.json')) return http.Response(jsonEncode(_chat), 200);
      return http.Response('{}', req.headers['x-goog-api-key'] == 'bad' ? 400 : 429);
    });
    final r = repo(client);
    expect(() => r.ask('q?', language: 'en', apiKey: ''), throwsA(isA<AskException>().having((e) => e.message, 'm', contains('Add your free'))));
    expect(() => r.ask('q?', language: 'en', apiKey: 'bad'), throwsA(isA<AskException>().having((e) => e.message, 'm', contains('did not accept'))));
    expect(() => r.ask('q?', language: 'en', apiKey: 'ok'), throwsA(isA<AskException>().having((e) => e.message, 'm', contains('free limit'))));
  });

  test('works without an app folder (web), straight from the network', () async {
    final client = MockClient((req) async => http.Response(jsonEncode(_updates), 200));
    final r = GithubRepository(baseUrl: 'https://data.test', client: client, cacheDir: () async => throw UnsupportedError('no folder'));
    expect((await r.feed().firstWhere((l) => l.isNotEmpty)).length, 2);
  });

  test('normalise and dot', () {
    expect(normalise([3, 4]), [0.6, 0.8]);
    expect(dot([0.6, 0.8], [0.6, 0.8]), closeTo(1, 1e-9));
  });
}
