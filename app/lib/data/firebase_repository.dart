import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/tax_update.dart';
import 'repository.dart';

class FirebaseRepository implements UpdatesRepository {
  FirebaseRepository({FirebaseFirestore? db, FirebaseFunctions? functions, FirebaseMessaging? messaging})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseMessaging _messaging;

  @override
  bool get isPreview => false;

  @override
  Stream<List<TaxUpdate>> feed({String? topic, int limit = 50}) {
    Query<Map<String, dynamic>> q = _db.collection('updates');
    if (topic != null) q = q.where('topics', arrayContains: topic);
    return q
        .orderBy('sortDate', descending: true)
        .orderBy('firstSeenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TaxUpdate.fromDoc).toList());
  }

  @override
  Future<TaxUpdate?> byId(String id) async {
    final doc = await _db.collection('updates').doc(id).get();
    return doc.exists ? TaxUpdate.fromDoc(doc) : null;
  }

  @override
  Future<AskResult> ask(String question, {required String language}) async {
    try {
      final res = await _functions
          .httpsCallable('askTaxQuestion', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call<Map<Object?, Object?>>({'question': question, 'language': language});
      final d = res.data;
      return AskResult(
        answer: d['answer'] as String? ?? '',
        confident: d['confident'] == true,
        remainingToday: d['remainingToday'] as int?,
        sources: ((d['sources'] as List?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map(AskSource.fromMap)
            .toList(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw AskException(e.message ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  Future<void> report({required String kind, required String targetId, String? question, String? answer}) {
    return _db.collection('reports').add({
      'kind': kind,
      'targetId': targetId,
      'question': question,
      'answer': answer,
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setFollowing(String topicId, bool follow) async {
    if (follow) {
      await _messaging.requestPermission();
      await _messaging.subscribeToTopic('topic-$topicId');
    } else {
      await _messaging.unsubscribeFromTopic('topic-$topicId');
    }
  }
}
