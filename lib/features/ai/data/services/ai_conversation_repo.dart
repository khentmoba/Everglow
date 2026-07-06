import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/ai_conversation.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';

/// Firestore CRUD for AI conversations and session archives.
class AIConversationRepository implements IAIConversationRepository {
  final FirebaseFirestore _db;
  final User? _user;

  // Feature-specific conversation caches
  AIConversation? _assistantConversation;
  AIConversation? _guardianConversation;
  AIConversation? _recommendationConversation;
  AIConversation? _dateIdeaConversation;

  AIConversationRepository({FirebaseFirestore? db, User? user})
      : _db = db ?? FirebaseFirestore.instance,
        _user = user;

  AIConversation? get assistant => _assistantConversation;
  AIConversation? get guardian => _guardianConversation;

  AIConversation? _get(String feature) {
    switch (feature) {
      case 'assistant': return _assistantConversation;
      case 'guardian': return _guardianConversation;
      case 'recommendations': return _recommendationConversation;
      case 'date_ideas': return _dateIdeaConversation;
      default: return null;
    }
  }

  void _set(String feature, AIConversation? conv) {
    switch (feature) {
      case 'assistant': _assistantConversation = conv; break;
      case 'guardian': _guardianConversation = conv; break;
      case 'recommendations': _recommendationConversation = conv; break;
      case 'date_ideas': _dateIdeaConversation = conv; break;
    }
  }

  void setConversation(String feature, AIConversation? conv) => _set(feature, conv);

  /// Get or create a conversation for a feature, with Firestore fallback.
  Future<AIConversation> getOrCreate(String feature) async {
    final cached = _get(feature);
    if (cached != null) return cached;

    final uid = _user?.uid ?? '';
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
    } catch (_) {}

    final conv = AIConversation(id: feature, feature: feature);
    _set(feature, conv);
    return conv;
  }

  /// Persist a conversation to Firestore.
  Future<void> save(AIConversation conversation) async {
    final uid = _user?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(conversation.id)
          .set(conversation.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save AI conversation: $e');
    }
  }

  /// Archive a conversation as a session snapshot.
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

      await _trimFullSessions();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to archive session: $e');
    }
  }

  /// Keep max 5 full sessions; summarize older ones.
  Future<void> _trimFullSessions() async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .where('hasSummary', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.length <= 5) return;

      final toSummarize = snapshot.docs.toList().skip(5).toList();
      for (final doc in toSummarize) {
        final data = doc.data();
        final messages = data['messages'] as List? ?? [];
        final summary = _buildLocalSummary(messages);
        await doc.reference.update({
          'hasSummary': true,
          'summary': summary,
          'messages': [],
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to trim sessions: $e');
    }
  }

  /// Build a concise topic-based summary from session messages.
  /// Extracts what the user asked/talked about, deduplicates, and
  /// produces a readable summary Mochi can actually use later.
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
        // Take the first meaningful sentence as the topic gist
        final firstSentence = content.split(RegExp(r'[.?!\n]')).first.trim();
        if (firstSentence.length >= 8) {
          final gist = firstSentence.length > 80
              ? '${firstSentence.substring(0, 80)}…'
              : firstSentence;
          // Deduplicate against near-matches
          final key = gist.substring(0, gist.length > 20 ? 20 : gist.length).toLowerCase();
          if (seen.add(key) && topics.length < 8) {
            topics.add(gist);
          }
        }
      }
    }

    if (topics.isEmpty) return '$exchangeCount exchanges (no clear topics)';
    return '$exchangeCount topics — ${topics.join(' • ')}';
  }

  /// Load the last 3 full sessions' messages into a conversation.
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Merge messages from all loaded sessions (oldest first)
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

  /// Clear a feature's conversation and delete from Firestore.
  Future<void> clear(String feature) async {
    final conv = _get(feature);
    if (conv != null && conv.messages.length >= 2) {
      await archiveSession(conv);
    }

    _set(feature, null);

    final uid = _user?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(feature)
          .delete();
    } catch (_) {}
  }

  /// Load assistant conversation from cache or Firestore.
  Future<void> loadAssistant() async {
    if (_assistantConversation != null) return;
    final conv = await getOrCreate('assistant');
    if (conv.messages.isEmpty) {
      await loadSessionIntoConversation(conv);
    }
  }

  /// Clear all cached conversations (start fresh).
  void startFresh() {
    _assistantConversation = null;
    _guardianConversation = null;
    _recommendationConversation = null;
    _dateIdeaConversation = null;
  }
}
