@TestOn('browser')
library;

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeConversationRepo implements IAIConversationRepository {
  _FakeConversationRepo(this.conversation);

  AIConversation? conversation;

  @override
  AIConversation? get assistant => conversation;

  @override
  AIConversation? get guardian => null;

  @override
  void setConversation(String feature, AIConversation? conv) {
    if (feature == 'assistant') conversation = conv;
  }

  @override
  Future<AIConversation> getOrCreate(String feature) async =>
      conversation ??= AIConversation(id: feature, feature: feature);

  @override
  Future<void> save(AIConversation conversation) async {}

  @override
  Future<void> archiveSession(AIConversation conversation) async {}

  @override
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {}

  @override
  Future<void> clear(String feature, {bool archive = true}) async {
    if (feature == 'assistant') {
      conversation = AIConversation(id: feature, feature: feature);
    }
  }

  @override
  Future<void> loadAssistant() async {}

  @override
  void startFresh() => conversation = null;

  @override
  Future<List<AISession>> listSessions({int limit = 50}) async => const [];

  @override
  Stream<List<AISession>> watchSessions({int limit = 50}) =>
      const Stream.empty();

  @override
  Future<void> loadSession(String sessionId) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}
}

class _FakeMemoryRepo implements IAIMemoryRepository {
  @override
  List<String> get all => const [];

  @override
  List<MemoryFact> get facts => const [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {}

  @override
  Future<void> save(String fact, {String category = 'fact'}) async {}

  @override
  Future<void> saveStructured({
    required String fact,
    String? category = 'fact',
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

class _StreamingAIService extends AIService {
  _StreamingAIService({
    required super.memoryRepo,
    required super.conversationRepo,
  });

  String streamedText = '';

  @override
  bool get isLoading => true;

  @override
  String get draftResponse => streamedText;

  void stream(String text) {
    streamedText = text;
    draftResponseNotifier.value = text;
    draftRevisionNotifier.value++;
  }
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => 'clairjassen';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('chat leaves room to type on phone and tablet', (tester) async {
    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Message Motchi…',
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 820.0]) {
      tester.view.physicalSize = Size(width, 1000);
      final ai = AIService(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: _FakeConversationRepo(
          AIConversation(
            id: 'demo',
            feature: 'assistant',
            messages: [
              AIMessage(role: 'user', content: 'Hello Motchi'),
              AIMessage(
                role: 'assistant',
                content: '**A little help**\n- One thing\n- Another thing',
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AIService>.value(value: ai),
            ChangeNotifierProvider<AuthService>.value(
              value: _FakeAuthService(),
            ),
          ],
          child: MaterialApp(key: ValueKey(width), home: const MotchiScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(composer).width, greaterThan(width * 0.65));
      expect(find.text('Whispered for you two 🐾'), findsNothing);
      expect(find.text('Plan a date 🥂'), findsNothing);
      await tester.enterText(composer, 'A cozy night in');
      await tester.pump();
      expect(find.text('A cozy night in'), findsOneWidget);
      // Switching layouts keeps the controller but replaces the composer.
      for (final resizedWidth in [1280.0, 390.0]) {
        tester.view.physicalSize = Size(resizedWidth, 1000);
        await tester.pump();
        await tester.pump();
        final send = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Send message',
          ),
        );
        expect(send.onPressed, isNotNull);
        await tester.enterText(composer, 'Still cozy');
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      ai.dispose();
    }
  });

  testWidgets('keeps the latest streamed reply in view', (tester) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final oldReply = List.filled(
      12,
      'An earlier reply with enough text to make the conversation scroll.',
    ).join('\n');
    final conversation = AIConversation(
      id: 'assistant',
      feature: 'assistant',
      messages: [
        AIMessage(role: 'user', content: 'Tell me a long story.'),
        for (var i = 0; i < 5; i++)
          AIMessage(role: 'assistant', content: oldReply),
      ],
    );
    final repo = _FakeConversationRepo(conversation);
    final ai = _StreamingAIService(
      memoryRepo: _FakeMemoryRepo(),
      conversationRepo: repo,
    );
    addTearDown(ai.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AIService>.value(value: ai),
          ChangeNotifierProvider<AuthService>.value(value: _FakeAuthService()),
        ],
        child: const MaterialApp(home: MotchiScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final listFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ListView &&
          widget.controller != null &&
          widget.scrollDirection == Axis.vertical,
    );
    final list = tester.widget<ListView>(listFinder);
    final controller = list.controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    ai.stream(
      List.filled(30, 'A newly streamed line of Motchi text.').join('\n'),
    );
    await tester.pump();
    await tester.pump();

    expect(
      controller.position.pixels,
      closeTo(controller.position.maxScrollExtent, 1),
    );
  });
}
