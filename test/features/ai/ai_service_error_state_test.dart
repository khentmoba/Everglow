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
  Completer<void>? sessionGate;
  Completer<void>? clearGate;
  Object? sessionError;
  AIConversation? loadedConversation;
  int getOrCreateCalls = 0;

  @override
  AIConversation? get assistant => assistantConv;

  @override
  AIConversation? get guardian => null;

  @override
  void setConversation(String feature, AIConversation? conv) {
    if (feature == 'assistant') assistantConv = conv;
  }

  @override
  Future<AIConversation> getOrCreate(String feature) async {
    getOrCreateCalls++;
    return assistantConv ??= AIConversation(id: feature, feature: feature);
  }

  @override
  Future<void> save(AIConversation conversation) async {}

  @override
  Future<void> archiveSession(AIConversation conversation) async {}

  @override
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {}

  @override
  Future<void> clear(String feature, {bool archive = true}) async {
    await clearGate?.future;
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
  Stream<List<AISession>> watchSessions({int limit = 50}) =>
      const Stream.empty();

  @override
  Future<void> loadSession(String sessionId) async {
    await sessionGate?.future;
    if (sessionError != null) throw sessionError!;
    if (loadedConversation != null) assistantConv = loadedConversation;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    archived.removeWhere((s) => s.id == sessionId);
  }
}

class _FakeMemoryRepo implements IAIMemoryRepository {
  int loadCalls = 0;
  @override
  List<String> get all => [];

  @override
  List<MemoryFact> get facts => [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {
    loadCalls++;
  }

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
  test(
    'opening history blocks sends and other navigation until it finishes',
    () async {
      final oldConversation = AIConversation(
        id: 'assistant',
        feature: 'assistant',
        messages: [AIMessage(role: 'user', content: 'Old conversation')],
      );
      final loaded = AIConversation(
        id: 'assistant',
        feature: 'assistant',
        messages: [AIMessage(role: 'user', content: 'Archived conversation')],
      );
      final repo = _FakeConversationRepo()
        ..assistantConv = oldConversation
        ..loadedConversation = loaded
        ..sessionGate = Completer<void>();
      final ai = AIService(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: repo,
      );
      final originalId = ai.currentSessionId;
      final busyChanges = <bool>[];
      ai.addListener(() => busyChanges.add(ai.isNavigating));
      final opening = ai.switchSession('archived');
      expect(ai.isNavigating, isTrue);
      expect(ai.isLoading, isFalse);
      expect(ai.currentSessionId, originalId);
      await expectLater(
        ai.sendMessage(
          feature: 'assistant',
          message: 'Do not send',
          callerName: 'clairjassen',
        ),
        throwsStateError,
      );
      await expectLater(ai.clearConversation('assistant'), throwsStateError);
      await expectLater(ai.switchSession('other'), throwsStateError);
      expect(repo.getOrCreateCalls, 0);
      expect(oldConversation.messages.single.content, 'Old conversation');
      repo.sessionGate!.complete();
      await opening;
      expect(ai.isNavigating, isFalse);
      expect(ai.currentSessionId, 'archived');
      expect(ai.assistantConversation, same(loaded));
      expect(busyChanges, [true, false]);
      ai.dispose();
    },
  );

  test(
    'failed history opening keeps the session id and unlocks navigation',
    () async {
      final repo = _FakeConversationRepo()
        ..sessionError = StateError('offline');
      final ai = AIService(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: repo,
      );
      final originalId = ai.currentSessionId;
      await expectLater(ai.switchSession('missing'), throwsStateError);
      expect(ai.currentSessionId, originalId);
      expect(ai.isNavigating, isFalse);
      repo.sessionError = null;
      await ai.switchSession('available');
      expect(ai.currentSessionId, 'available');
      ai.dispose();
    },
  );

  test('new chat blocks a reply and session load while clearing', () async {
    final repo = _FakeConversationRepo()..clearGate = Completer<void>();
    final ai = AIService(memoryRepo: _FakeMemoryRepo(), conversationRepo: repo);
    final originalId = ai.currentSessionId;
    final clearing = ai.clearConversation('assistant');
    expect(ai.isNavigating, isTrue);
    expect(ai.currentSessionId, originalId);
    await expectLater(
      ai.sendMessage(
        feature: 'assistant',
        message: 'Do not send',
        callerName: 'clairjassen',
      ),
      throwsStateError,
    );
    await expectLater(ai.switchSession('archived'), throwsStateError);
    repo.clearGate!.complete();
    await clearing;
    expect(ai.isNavigating, isFalse);
    expect(ai.currentSessionId, isNot(originalId));
    ai.dispose();
  });

  test('failed new chat keeps its session id and unlocks navigation', () async {
    final repo = _FakeConversationRepo()..clearGate = Completer<void>();
    final ai = AIService(memoryRepo: _FakeMemoryRepo(), conversationRepo: repo);
    final originalId = ai.currentSessionId;
    final clearing = ai.clearConversation('assistant');
    final failure = expectLater(clearing, throwsStateError);
    repo.clearGate!.completeError(StateError('offline'));
    await failure;
    expect(ai.currentSessionId, originalId);
    expect(ai.isNavigating, isFalse);
    ai.dispose();
  });

  test('opening chat does not load the Memory Book', () async {
    final memories = _FakeMemoryRepo();
    final ai = AIService(
      memoryRepo: memories,
      conversationRepo: _FakeConversationRepo(),
    );
    await ai.loadAssistantConversation();
    expect(memories.loadCalls, 0);
    expect(ai.assistantConversation, isNotNull);
    ai.dispose();
  });

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
