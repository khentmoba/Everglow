import 'dart:async';

import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeConversationRepo implements IAIConversationRepository {
  AIConversation? assistantConv;
  List<AISession> archived = [];
  final _controller = StreamController<List<AISession>>.broadcast();

  void emitArchived(List<AISession> sessions) {
    archived = List.of(sessions);
    _controller.add(archived);
  }

  void dispose() => _controller.close();

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
  Stream<List<AISession>> watchSessions({int limit = 50}) => _controller.stream;

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

AISession _session(String id, String title, {String? summary}) => AISession(
  id: id,
  feature: 'assistant',
  messageCount: 4,
  hasSummary: summary != null,
  summary: summary,
  createdAt: DateTime.now(),
  title: title,
);

void main() {
  late _FakeConversationRepo convRepo;
  late AIService ai;

  setUp(() {
    convRepo = _FakeConversationRepo();
    ai = AIService(memoryRepo: _FakeMemoryRepo(), conversationRepo: convRepo);
  });

  tearDown(() {
    ai.dispose();
    convRepo.dispose();
  });

  Future<void> pumpSidebar(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AIService>.value(
        value: ai,
        child: const MaterialApp(
          home: Scaffold(
            body: MotchiSidebar(isOpen: true, onClose: _noop, onNewChat: _noop),
          ),
        ),
      ),
    );
    convRepo.emitArchived([]);
    await tester.pump();
  }

  testWidgets(
    'archived sessions pushed by the stream appear with no refresh tap',
    (tester) async {
      await pumpSidebar(tester);
      expect(find.textContaining('No conversations yet'), findsOneWidget);

      convRepo.emitArchived([_session('a', 'Hello Motchi')]);
      await tester.pump();

      expect(find.text('Hello Motchi'), findsOneWidget);
      expect(find.textContaining('No conversations yet'), findsNothing);
    },
  );

  testWidgets('removed sessions disappear when the stream emits', (
    tester,
  ) async {
    await pumpSidebar(tester);
    convRepo.emitArchived([
      _session('a', 'First chat'),
      _session('b', 'Second chat'),
    ]);
    await tester.pump();
    expect(find.text('First chat'), findsOneWidget);
    expect(find.text('Second chat'), findsOneWidget);

    convRepo.emitArchived([_session('b', 'Second chat')]);
    await tester.pump();

    expect(find.text('First chat'), findsNothing);
    expect(find.text('Second chat'), findsOneWidget);
  });

  testWidgets('current conversation shows as soon as AIService notifies', (
    tester,
  ) async {
    await pumpSidebar(tester);
    expect(find.textContaining('No conversations yet'), findsOneWidget);

    convRepo.assistantConv = AIConversation(
      id: 'assistant',
      feature: 'assistant',
      messages: [AIMessage(role: 'user', content: 'Hi Motchi')],
    );
    ai.notifyListeners();
    await tester.pump();

    expect(find.text('Hi Motchi'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('clearing the chat removes the live entry without refresh', (
    tester,
  ) async {
    await pumpSidebar(tester);
    convRepo.assistantConv = AIConversation(
      id: 'assistant',
      feature: 'assistant',
      messages: [AIMessage(role: 'user', content: 'Hi Motchi')],
    );
    ai.notifyListeners();
    await tester.pump();
    expect(find.text('Hi Motchi'), findsOneWidget);

    convRepo.assistantConv = AIConversation(
      id: 'assistant',
      feature: 'assistant',
    );
    ai.notifyListeners();
    await tester.pump();

    expect(find.text('Hi Motchi'), findsNothing);
    expect(find.textContaining('No conversations yet'), findsOneWidget);
  });

  testWidgets('motchi hub shortcuts render properly', (tester) async {
    await pumpSidebar(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    expect(find.text('Trivia'), findsOneWidget);
  });

  testWidgets('search filters sessions and shows clear option', (tester) async {
    await pumpSidebar(tester);
    convRepo.emitArchived([
      _session('a', 'Movie night ideas'),
      _session('b', 'Dinner recipe with pasta'),
    ]);
    await tester.pump();

    expect(find.text('Movie night ideas'), findsOneWidget);
    expect(find.text('Dinner recipe with pasta'), findsOneWidget);

    // Enter query 'movie'
    await tester.enterText(find.byType(TextField), 'movie');
    await tester.pump();

    expect(find.text('Movie night ideas'), findsOneWidget);
    expect(find.text('Dinner recipe with pasta'), findsNothing);
    expect(find.text('filtered'), findsOneWidget);

    // Enter non-matching query
    await tester.enterText(find.byType(TextField), 'astronaut');
    await tester.pump();

    expect(find.text('Movie night ideas'), findsNothing);
    expect(find.textContaining('No matches for “astronaut”'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);

    // Tap clear search
    await tester.tap(find.text('Clear search'));
    await tester.pump();

    expect(find.text('Movie night ideas'), findsOneWidget);
    expect(find.text('Dinner recipe with pasta'), findsOneWidget);
  });

  testWidgets('session summary preview is displayed when present', (
    tester,
  ) async {
    await pumpSidebar(tester);
    convRepo.emitArchived([
      _session(
        'a',
        'Starlight memories',
        summary: 'Talked about stargazing trip in Palawan',
      ),
    ]);
    await tester.pump();

    expect(find.text('Starlight memories'), findsOneWidget);
    expect(
      find.text('Talked about stargazing trip in Palawan'),
      findsOneWidget,
    );
  });
}

void _noop() {}
