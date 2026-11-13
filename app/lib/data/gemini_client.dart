import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'repository.dart';

/// Calls the Gemini API directly from the phone with the user's own free
/// Google AI Studio key. Fine for an app only you use; a public app would
/// need a server so the key isn't on people's phones.
class GeminiClient {
  GeminiClient({http.Client? client, this.model = 'gemini-3.8-flash', this.embeddingModel = 'gemini-embedding-001'})
      : _http = client ?? http.Client();

  final http.Client _http;
  final String model;
  final String embeddingModel;

  /// Must match the collector (EMBEDDING_DIMENSIONS).
  static const dimensions = 256;
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  Future<Map<String, dynamic>> _post(String path, String apiKey, Map<String, Object?> body) async {
    final res = await _http
        .post(Uri.parse('$_base/$path'),
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode == 429) {
      throw AskException("Gemini's free limit is used up for now. Please try again in a while.");
    }
    if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
      throw AskException('Gemini did not accept your API key. Check it in Settings.');
    }
    if (res.statusCode != 200) {
      throw AskException('Gemini is not responding (error ${res.statusCode}). Please try again.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Unit-length query vector, comparable with the collector's document vectors.
  Future<List<double>> embedQuery(String text, String apiKey) async {
    final d = await _post('$embeddingModel:embedContent', apiKey, {
      'content': {
        'parts': [
          {'text': text}
        ]
      },
      'taskType': 'RETRIEVAL_QUERY',
      'outputDimensionality': dimensions,
    });
    final values = ((d['embedding'] as Map?)?['values'] as List?)?.map((v) => (v as num).toDouble()).toList();
    if (values == null || values.isEmpty) throw AskException('Gemini returned an empty answer. Please try again.');
    return normalise(values);
  }

  Future<Map<String, dynamic>> generateJson({
    required String apiKey,
    required String system,
    required String prompt,
    required Map<String, Object?> schema,
  }) async {
    final d = await _post('$model:generateContent', apiKey, {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json', 'responseJsonSchema': schema, 'temperature': 0.2},
    });
    final parts = (((d['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?;
    final text = parts?.map((p) => (p as Map)['text'] ?? '').join();
    if (text == null || text.isEmpty) throw AskException('Gemini returned an empty answer. Please try again.');
    return jsonDecode(text) as Map<String, dynamic>;
  }
}

List<double> normalise(List<double> v) {
  final len = sqrt(v.fold<double>(0, (s, x) => s + x * x));
  return len == 0 ? v : v.map((x) => x / len).toList();
}

/// Dot product of two unit vectors = cosine similarity.
double dot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < min(a.length, b.length); i++) {
    s += a[i] * b[i];
  }
  return s;
}
