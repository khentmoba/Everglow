import 'dart:async';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
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
  Future<List<AISession>> listSessions({int limit = 50}) async => [];

  @override
  Stream<List<AISession>> watchSessions({int limit = 50}) =>
      Stream.value([]);

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
  bool _loading = false;

  @override
  bool get isLoading => _loading;

  @override
  String get draftResponse => streamedText;

  void startStreaming() {
    _loading = true;
    notifyListeners();
  }

  void stopStreaming() {
    _loading = false;
    notifyListeners();
  }

  void stream(String text) {
    streamedText = text;
    draftResponseNotifier.value = text;
    draftRevisionNotifier.value++;
  }
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isAgentSession => false;
  @override
  String? get currentUser => 'clair';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('when motchi chat has an answer, user can scroll up freely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longAnswer = List.generate(
      40,
      (i) => 'Paragraph $i of Motchi answer text with detailed explanation.',
    ).join('\n\n');
    final conversation = AIConversation(
      id: 'assistant',
      feature: 'assistant',
      messages: [
        AIMessage(role: 'user', content: 'Tell me a long story.'),
        AIMessage(role: 'assistant', content: longAnswer),
      ],
    );
    final repo = _FakeConversationRepo(conversation);
    final ai = AIService(
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
        child: MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: const MotchiScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ListView &&
          widget.controller != null &&
          widget.scrollDirection == Axis.vertical,
    );
    final list = tester.widget<ListView>(listFinder);
    final controller = list.controller!;

    expect(controller.position.maxScrollExtent, greaterThan(200));
    final maxScroll = controller.position.maxScrollExtent;
    expect(controller.position.pixels, closeTo(maxScroll, 1));

    // User scrolls up by dragging
    await tester.drag(listFinder, const Offset(0, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.position.pixels, lessThan(maxScroll - 20));

    // After settling frames, user position is maintained (no snap back to bottom)
    await tester.pumpAndSettle();
    expect(controller.position.pixels, lessThan(maxScroll - 20));
  });

  testWidgets(
    'short conversation with < 120px scroll extent still allows scrolling up',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Just slightly taller than the screen
      final moderateAnswer = List.generate(
        12,
        (i) => 'Line $i of moderate answer.',
      ).join('\n');
      final conversation = AIConversation(
        id: 'assistant',
        feature: 'assistant',
        messages: [
          AIMessage(role: 'user', content: 'Quick question'),
          AIMessage(role: 'assistant', content: moderateAnswer),
        ],
      );
      final repo = _FakeConversationRepo(conversation);
      final ai = AIService(
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
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: const MotchiScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ListView &&
            widget.controller != null &&
            widget.scrollDirection == Axis.vertical,
      );
      final list = tester.widget<ListView>(listFinder);
      final controller = list.controller!;

      final maxScroll = controller.position.maxScrollExtent;
      expect(maxScroll, greaterThan(10));

      // Scroll to the top (pixels = 0)
      controller.jumpTo(0);
      await tester.pump();
      await tester.pumpAndSettle();

      // Ensure it stays at 0 and is not yanked back to maxScrollExtent
      expect(controller.position.pixels, 0);
    },
  );

  testWidgets(
    'streaming follows bottom, but pauses following when user scrolls up',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final conversation = AIConversation(
        id: 'assistant',
        feature: 'assistant',
        messages: [
          AIMessage(role: 'user', content: 'Long request'),
          AIMessage(
            role: 'assistant',
            content: List.filled(20, 'Existing reply text').join('\n'),
          ),
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
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: const MotchiScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ListView &&
            widget.controller != null &&
            widget.scrollDirection == Axis.vertical,
      );
      final list = tester.widget<ListView>(listFinder);
      final controller = list.controller!;

      // Start streaming
      ai.startStreaming();
      ai.stream(List.filled(20, 'Stream chunk 1').join('\n'));
      await tester.pump();
      await tester.pump();

      // Following is active: should be at bottom
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 1),
      );

      // User scrolls up during streaming by > 300px so the Latest message button appears
      await tester.drag(listFinder, const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final scrolledUpPosition = controller.position.pixels;
      expect(scrolledUpPosition, lessThan(controller.position.maxScrollExtent - 250));

      // Stream more tokens while user is scrolled up
      ai.stream(List.filled(40, 'Stream chunk 2 with more lines').join('\n'));
      await tester.pump();
      await tester.pump();

      // Motchi should NOT have yanked the user back to bottom
      expect(controller.position.pixels, closeTo(scrolledUpPosition, 5));

      // Latest message button appears when scrolled away
      final latestBtn = find.widgetWithText(FilledButton, 'Latest message');
      expect(latestBtn, findsOneWidget);

      // The post-frame callback schedules the animation; its first tick starts it.
      await tester.tap(latestBtn);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump();
      }

      // Now back at bottom and following
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    },
  );
}
