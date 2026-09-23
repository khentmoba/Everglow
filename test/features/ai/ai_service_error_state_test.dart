import 'dart:async';

import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConversationRepo implements IAIConversationRepository {
  AIConversation? assistantConv;
  List<AISession> archived = [];

  @override
  AIConversation? get assistant => assistantConv;

  @override
  AIConversation? get guardian => null;

  @override
  void setConversation(String feature, AIConversation? conv) {
    if (feature == 'assistant') assistantConv = conv;
  }

  @override
  Future<AIConversation> getOrCreate(String feature) async =>
      assistantConv ??= AIConversation(id: feature, feature: feature);

  @override
  Future<void> save(AIConversation conversation) async {}

  @override
  Future<void> archiveSession(AIConversation conversation) async {}

  @override
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {}

  @override
  Future<void> clear(String feature, {bool archive = true}) async {
    if (feature == 'assistant') {
      assistantConv = AIConversation(id: feature, feature: feature);
    }
  }

  @override
  Future<void> loadAssistant() async {
    await getOrCreate('assistant');
  }

  @override
  void startFresh() {
    assistantConv = null;
  }

  @override
  Future<List<AISession>> listSessions({int limit = 50}) async => archived;

  @override
  Stream<List<AISession>> watchSessions({int limit = 50}) => const Stream.empty();

  @override
  Future<void> loadSession(String sessionId) async {}

  @override
  Future<void> deleteSession(String sessionId) async {
    archived.removeWhere((s) => s.id == sessionId);
  }
}

class _FakeMemoryRepo implements IAIMemoryRepository {
  @override
  List<String> get all => [];

  @override
  List<MemoryFact> get facts => [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {}

  @override
  Future<void> save(String fact, {String category = 'fact'}) async {}

  @override
  Future<void> saveStructured({
    required String fact,
    String category = 'fact',
    String? subject,
    String? relation,
    String? object,
    DateTime? occurredAt,
  }) async {}

  @override
  Future<void> delete(String factId) async {}

  @override
  Future<void> setPinned(String factId, bool pinned) async {}

  @override
  bool isDuplicate(String fact) => false;

  @override
  void reset() {}
}

void main() {
  test('AIService starts with null lastError and cleans up on cancel', () {
    final ai = AIService(
      memoryRepo: _FakeMemoryRepo(),
      conversationRepo: _FakeConversationRepo(),
    );

    expect(ai.lastError, isNull);
    expect(ai.isLoading, isFalse);

    // Cancel when not loading is a no-op
    expect(ai.cancelCurrentReply(), isFalse);
    expect(ai.lastError, isNull);

    ai.dispose();
  });

  test('AIService maintains and cycles currentSessionId', () async {
    final ai = AIService(
      memoryRepo: _FakeMemoryRepo(),
      conversationRepo: _FakeConversationRepo(),
    );

    final sess1 = ai.currentSessionId;
    expect(sess1, isNotEmpty);
    expect(sess1.startsWith('sess_'), isTrue);

    // Same session ID across multiple reads
    expect(ai.currentSessionId, equals(sess1));

    // Clearing conversation (new chat) cycles the session ID
    await ai.clearConversation('assistant', archive: true);
    final sess2 = ai.currentSessionId;
    expect(sess2, isNotEmpty);
    expect(sess2, isNot(equals(sess1)));

    // startFreshSession cycles the session ID as well
    ai.startFreshSession();
    final sess3 = ai.currentSessionId;
    expect(sess3, isNotEmpty);
    expect(sess3, isNot(equals(sess2)));

    ai.dispose();
  });
}
