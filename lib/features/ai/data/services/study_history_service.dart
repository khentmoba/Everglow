import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'study_doc_service.dart';

/// One persisted Q&A turn in a Study session.
class StudyHistoryTurn {
  final bool fromUser;
  final String text;

  const StudyHistoryTurn.user(this.text) : fromUser = true;
  const StudyHistoryTurn.assistant(this.text) : fromUser = false;

  String get role => fromUser ? 'user' : 'assistant';

  Map<String, String> toJson() => {'role': role, 'content': text};

  factory StudyHistoryTurn.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'user';
    final content = json['content'] as String? ?? '';
    return role == 'assistant'
        ? StudyHistoryTurn.assistant(content)
        : StudyHistoryTurn.user(content);
  }
}

/// A persisted Study session: attached PDF sources + Q&A turns.
///
/// Lives in `ai_memories/shared/study_sessions` — separate from the generic
/// `sessions` collection so Mochi's auto-archive/trim logic never touches
/// study history.
class StudySession {
  final String id;
  final String title;
  final List<String> sourceNames;
  final List<StudyDoc> sources;
  final List<StudyHistoryTurn> turns;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySession({
    required this.id,
    required this.title,
    required this.sourceNames,
    required this.sources,
    required this.turns,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Builds a readable session title from the first user question.
String studySessionTitle(List<StudyHistoryTurn> turns) {
  for (final turn in turns) {
    if (!turn.fromUser) continue;
    final oneLine = turn.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.isEmpty) continue;
    if (oneLine.length <= 60) return oneLine;
    return '${oneLine.substring(0, 60).trimRight()}…';
  }
  return 'Untitled study';
}

/// Firestore CRUD for Study session history.
///
/// Shared between Khent and Clair (couple-only, enforced by rules).
/// All failures are swallowed (debug-logged) so history never breaks chat.
class StudyHistoryService {
  final FirebaseFirestore _db;

  StudyHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ai_memories').doc('shared').collection('study_sessions');

  /// Creates a new session when [sessionId] is null, otherwise updates it.
  /// Returns the session id, or null when there is nothing worth saving or
  /// the write failed.
  Future<String?> saveSession({
    String? sessionId,
    required List<StudyDoc> sources,
    required List<StudyHistoryTurn> turns,
  }) async {
    if (sources.isEmpty && turns.isEmpty) return sessionId;

    final title = turns.isEmpty
        ? (sources.isEmpty
              ? 'Untitled study'
              : '${sources.length} source${sources.length == 1 ? '' : 's'} — ${sources.first.fileName}')
        : studySessionTitle(turns);

    // Cap stored turns so the doc stays under the 100 KB rule limit
    // (sources are already capped at ~30k chars by the study shelf).
    final storedTurns = turns.length > 60
        ? turns.sublist(turns.length - 60)
        : turns;

    final payload = <String, dynamic>{
      'title': title,
      'sourceNames': sources.map((d) => d.fileName).toList(),
      'sources': [
        for (final d in sources)
          {
            'fileName': d.fileName,
            'text': d.text,
            'truncated': d.truncated,
          },
      ],
      'messages': [
        for (final t in storedTurns) {'role': t.role, 'content': t.text},
      ],
      'messageCount': storedTurns.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (sessionId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        final ref = await _col.add(payload);
        return ref.id;
      }
      await _col.doc(sessionId).set(payload, SetOptions(merge: true));
      return sessionId;
    } catch (e) {
      if (kDebugMode) debugPrint('[StudyHistory] save failed: $e');
      return sessionId;
    }
  }

  /// Lists sessions newest-first by last activity.
  Future<List<StudySession>> listSessions({int limit = 30}) async {
    try {
      final snap = await _col
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(_fromDoc).toList();
    } catch (e) {
      // Fallback for older docs missing `updatedAt`: order by creation time.
      try {
        final snap = await _col
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        final sessions = snap.docs.map(_fromDoc).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return sessions;
      } catch (e2) {
        if (kDebugMode) debugPrint('[StudyHistory] list failed: $e2');
        return [];
      }
    }
  }

  /// Loads one full session (sources + turns) for restoring.
  Future<StudySession?> loadSession(String sessionId) async {
    try {
      final doc = await _col.doc(sessionId).get();
      if (!doc.exists || doc.data() == null) return null;
      return _fromDoc(doc);
    } catch (e) {
      if (kDebugMode) debugPrint('[StudyHistory] load failed: $e');
      return null;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _col.doc(sessionId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[StudyHistory] delete failed: $e');
      rethrow;
    }
  }

  StudySession _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final sourcesJson = data['sources'] as List? ?? [];
    final messagesJson = data['messages'] as List? ?? [];
    final sourceNames = (data['sourceNames'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        sourcesJson
            .map((s) => (s as Map)['fileName']?.toString() ?? 'PDF')
            .toList()
            .cast<String>();

    DateTime readTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final createdAt = readTime(data['createdAt']);
    final updatedAt = readTime(data['updatedAt'] ?? data['createdAt']);

    return StudySession(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String)
          : 'Untitled study',
      sourceNames: sourceNames,
      sources: sourcesJson.map((s) {
        final m = s as Map<String, dynamic>? ?? {};
        // Defensive cast: Firestore may return Map<dynamic, dynamic>.
        final map = Map<String, dynamic>.from(m);
        return StudyDoc(
          fileName: map['fileName'] as String? ?? 'PDF',
          text: map['text'] as String? ?? '',
          truncated: map['truncated'] as bool? ?? false,
        );
      }).toList(),
      turns: messagesJson.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        return StudyHistoryTurn.fromJson(map);
      }).toList(),
      messageCount:
          (data['messageCount'] as num?)?.toInt() ?? messagesJson.length,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
