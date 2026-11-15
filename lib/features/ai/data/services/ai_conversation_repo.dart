import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/ai_conversation.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import '../../../../core/utils/logger.dart';

class AIConversationRepository implements IAIConversationRepository {
  final FirebaseFirestore _db;
  final User? _userOverride;

  String get _uid =>
      _userOverride?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  AIConversation? _assistantConversation;
  AIConversation? _guardianConversation;
  AIConversation? _recommendationConversation;
  AIConversation? _dateIdeaConversation;

  AIConversationRepository({FirebaseFirestore? db, User? user})
    : _db = db ?? FirebaseFirestore.instance,
      _userOverride = user;

  @override
  AIConversation? get assistant => _assistantConversation;
  @override
  AIConversation? get guardian => _guardianConversation;

  AIConversation? _get(String feature) {
    switch (feature) {
      case 'assistant':
        return _assistantConversation;
      case 'guardian':
        return _guardianConversation;
      case 'recommendations':
        return _recommendationConversation;
      case 'date_ideas':
        return _dateIdeaConversation;
      default:
        return null;
    }
  }

  void _set(String feature, AIConversation? conv) {
    switch (feature) {
      case 'assistant':
        _assistantConversation = conv;
        break;
      case 'guardian':
        _guardianConversation = conv;
        break;
      case 'recommendations':
        _recommendationConversation = conv;
        break;
      case 'date_ideas':
        _dateIdeaConversation = conv;
        break;
    }
  }

  @override
  void setConversation(String feature, AIConversation? conv) =>
      _set(feature, conv);

  @override
  Future<AIConversation> getOrCreate(String feature) async {
    final cached = _get(feature);
    if (cached != null) return cached;

    final uid = _uid;
    if (uid.isEmpty) {
      final conv = AIConversation(
        id: 'local_${feature}_${DateTime.now().millisecondsSinceEpoch}',
        feature: feature,
      );
      _set(feature, conv);
      return conv;
    }

    try {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(feature);

      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final conv = AIConversation.fromJson(doc.data()!);
        _set(feature, conv);
        return conv;
      }
    } catch (e) {
      debugPrint(
        '[AIConversationRepository] Failed to load conversation from Firestore: $e',
      );
    }

    final conv = AIConversation(id: feature, feature: feature);
    _set(feature, conv);
    return conv;
  }

  @override
  Future<void> save(AIConversation conversation) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final now = DateTime.now();
      final payload = conversation.toJson();
      payload['updatedAt'] = now.toIso8601String();
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(conversation.feature)
          .set(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save AI conversation: $e');
    }
  }

  @override
  Future<void> archiveSession(AIConversation conversation) async {
    try {
      final messagesJson = conversation.messages
          .map((m) => m.toJson())
          .toList();

      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .add({
            'feature': conversation.feature,
            'messages': messagesJson,
            'messageCount': messagesJson.length,
            'hasSummary': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      unawaited(_trimFullSessions());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to archive session: $e');
    }
  }

  Future<void> _trimFullSessions() async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .where('hasSummary', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.length <= 8) return;

      final toSummarize = snapshot.docs.toList().skip(8).toList();
      for (final doc in toSummarize) {
        final data = doc.data();
        final messages = data['messages'] as List? ?? [];
        final summary = await _buildLLMSummary(messages);
        await doc.reference.update({
          'hasSummary': true,
          'summary': summary,
          'messages': [],
        });
      }

      await _compressOldSessions();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to trim sessions: $e');
    }
  }

  Future<String> _buildLLMSummary(List messages) async {
    if (messages.isEmpty) return 'Empty session';

    final userMessages = messages
        .where((m) => (m as Map<String, dynamic>)['role'] == 'user')
        .map((m) => (m as Map<String, dynamic>)['content'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .join('\n');

    if (userMessages.trim().length < 20) {
      return _buildLocalSummary(messages);
    }

    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      final response = await http
          .post(
            Uri.parse('https://proxyaiv2-6pr4gqobxa-uc.a.run.app'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'systemPrompt':
                  'Summarize this conversation in 2-3 sentences. Focus on key topics, decisions, and notable moments. Be concise.',
              'messages': [
                {'role': 'user', 'content': userMessages},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = (data['reply'] as String? ?? '').trim();
        if (summary.isNotEmpty) return summary;
      }
    } catch (e) {
      debugPrint(
        '[AIConversationRepository] Summary API call failed, falling back to local: $e',
      );
    }

    return _buildLocalSummary(messages);
  }

  Future<void> _compressOldSessions() async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .where('hasSummary', isEqualTo: true)
          .orderBy('createdAt')
          .limit(40)
          .get();

      if (snapshot.docs.length <= 20) return;

      final toMerge = snapshot.docs.take(snapshot.docs.length - 8).toList();
      final summaries = toMerge
          .map((d) => d.data()['summary'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .join('\n');

      if (summaries.isEmpty) return;

      String mergedSummary;
      try {
        final idToken =
            await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
        final response = await http
            .post(
              Uri.parse('https://proxyaiv2-6pr4gqobxa-uc.a.run.app'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({
                'systemPrompt':
                    'Merge these session summaries into one concise paragraph preserving key information.',
                'messages': [
                  {'role': 'user', 'content': summaries},
                ],
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          mergedSummary = (data['reply'] as String? ?? '').trim();
          if (mergedSummary.isEmpty) mergedSummary = summaries;
        } else {
          mergedSummary = summaries;
        }
      } catch (e, st) {
        Logger.e(
          'AIConversationRepo: summary merge call failed, keeping raw summaries',
          error: e,
          stackTrace: st,
        );
        mergedSummary = summaries;
      }

      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .add({
            'summary': mergedSummary,
            'hasSummary': true,
            'messages': [],
            'feature': 'assistant',
            'messageCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
      for (final doc in toMerge) {
        await doc.reference.delete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to compress sessions: $e');
    }
  }

  String _buildLocalSummary(List messages) {
    if (messages.isEmpty) return 'Empty session';
    final seen = <String>{};
    final topics = <String>[];
    int exchangeCount = 0;

    for (final msg in messages) {
      final m = msg as Map<String, dynamic>;
      final role = m['role'] as String? ?? '';
      final content = (m['content'] as String? ?? '').trim();
      if (content.isEmpty) continue;

      if (role == 'user') {
        exchangeCount++;
        final firstSentence = content.split(RegExp(r'[.?!\n]')).first.trim();
        if (firstSentence.length >= 8) {
          final gist = firstSentence.length > 80
              ? '${firstSentence.substring(0, 80)}…'
              : firstSentence;
          final key = gist
              .substring(0, gist.length > 20 ? 20 : gist.length)
              .toLowerCase();
          if (seen.add(key) && topics.length < 8) {
            topics.add(gist);
          }
        }
      }
    }

    if (topics.isEmpty) return '$exchangeCount exchanges (no clear topics)';
    return '$exchangeCount topics — ${topics.join(' • ')}';
  }

  @override
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) return;

      final allPastMessages = <AIMessage>[];
      for (final doc in snapshot.docs.reversed) {
        final data = doc.data();
        final hasSummary = data['hasSummary'] as bool? ?? true;
        if (hasSummary) continue;
        final msgsJson = data['messages'] as List? ?? [];
        if (msgsJson.isEmpty) continue;
        allPastMessages.addAll(
          msgsJson.map((m) => AIMessage.fromJson(m as Map<String, dynamic>)),
        );
      }

      if (allPastMessages.isEmpty) return;
      conversation.messages.insertAll(0, allPastMessages);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load last session: $e');
    }
  }

  @override
  Future<void> clear(String feature, {bool archive = true}) async {
    final conv = _get(feature);
    final toArchive = archive && conv != null && conv.messages.length >= 2
        ? conv
        : null;

    _set(feature, AIConversation(id: feature, feature: feature));

    if (toArchive != null) {
      await archiveSession(toArchive);
    }

    final uid = _uid;
    if (uid.isEmpty) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(feature)
          .delete();
    } catch (e) {
      debugPrint(
        '[AIConversationRepository] Failed to delete conversation: $e',
      );
    }
  }

  @override
  Future<void> loadAssistant() async {
    if (_assistantConversation != null) return;
    await getOrCreate('assistant');
  }

  @override
  void startFresh() {
    _assistantConversation = null;
    _guardianConversation = null;
    _recommendationConversation = null;
    _dateIdeaConversation = null;
  }

  Query<Map<String, dynamic>> _sessionsQuery({int limit = 50}) => _db
      .collection('ai_memories')
      .doc('shared')
      .collection('sessions')
      .where('feature', isEqualTo: 'assistant')
      .orderBy('createdAt', descending: true)
      .limit(limit);

  AISession _sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final messages = data['messages'] as List? ?? [];
    final hasSummary = data['hasSummary'] as bool? ?? true;
    final summary = data['summary'] as String?;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    String title = 'New conversation';
    if (hasSummary && summary != null && summary.isNotEmpty) {
      title = summary.length > 60 ? '${summary.substring(0, 60)}…' : summary;
    } else if (messages.isNotEmpty) {
      final firstUserMsg = messages.firstWhere(
        (m) => (m as Map<String, dynamic>)['role'] == 'user',
        orElse: () => null,
      );
      if (firstUserMsg != null) {
        final content =
            (firstUserMsg as Map<String, dynamic>)['content'] as String? ?? '';
        title = content.length > 60 ? '${content.substring(0, 60)}…' : content;
      }
    }

    return AISession(
      id: doc.id,
      feature: data['feature'] ?? 'assistant',
      messageCount: data['messageCount'] ?? messages.length,
      hasSummary: hasSummary,
      summary: summary,
      createdAt: createdAt,
      title: title,
    );
  }

  @override
  Future<List<AISession>> listSessions({int limit = 50}) async {
    try {
      final snapshot = await _sessionsQuery(limit: limit).get();
      return snapshot.docs.map(_sessionFromDoc).toList();
    } catch (e, st) {
      Logger.e('Failed to list sessions', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Stream<List<AISession>> watchSessions({int limit = 50}) {
    try {
      return _sessionsQuery(limit: limit).snapshots().map(
        (snapshot) => snapshot.docs.map(_sessionFromDoc).toList(),
      );
    } catch (e, st) {
      Logger.e('Failed to watch sessions', error: e, stackTrace: st);
      return Stream.error(e, st);
    }
  }

  @override
  Future<void> loadSession(String sessionId) async {
    try {
      final doc = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw StateError('Requested AI session does not exist');
      }

      final data = doc.data()!;
      final messages = data['messages'] as List? ?? [];
      final summary = data['summary'] as String?;
      final parsedMessages = messages
          .map((msg) => AIMessage.fromJson(msg as Map<String, dynamic>))
          .toList();
      if (parsedMessages.isEmpty && summary != null && summary.isNotEmpty) {
        parsedMessages.add(
          AIMessage(role: 'assistant', content: 'Summary: $summary'),
        );
      }

      final previous = _assistantConversation;
      _assistantConversation = AIConversation(
        id: previous?.id ?? 'assistant',
        feature: 'assistant',
        messages: parsedMessages,
        createdAt: previous?.createdAt,
        updatedAt: previous?.updatedAt,
      );
    } catch (e, st) {
      Logger.e('Failed to load session', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .doc(sessionId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to delete session: $e');
    }
  }
}
