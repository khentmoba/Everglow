@TestOn('browser')
library;

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_screen.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
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

class _InteractionAIService extends AIService {
  _InteractionAIService()
    : super(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: _FakeConversationRepo(
          AIConversation(id: 'demo', feature: 'assistant'),
        ),
      );

  bool loading = false;
  Completer<String>? pending;
  final requests = <({String message, bool? thinking, bool canvas})>[];

  @override
  bool get isLoading => loading;

  @override
  Future<String> sendMessage({
    required String feature,
    required String message,
    String? contextOverride,
    bool stream = false,
    bool? enableThinking,
    String? callerName,
    void Function(String)? onToolStatus,
    void Function(Map<String, dynamic>)? onToolResult,
    List<String> imageUrls = const [],
    bool canvasEnabled = true,
  }) {
    requests.add((
      message: message,
      thinking: enableThinking,
      canvas: canvasEnabled,
    ));
    assistantConversation!.messages.add(
      AIMessage(role: 'user', content: message),
    );
    loading = true;
    pending = Completer<String>();
    notifyListeners();
    return pending!.future;
  }

  @override
  bool cancelCurrentReply() {
    loading = false;
    pending?.complete('');
    pending = null;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets(
    'quiet welcome and composer fit small phones, tablets and keyboards',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      for (final width in [320.0, 390.0, 820.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 844);
        final ai = _InteractionAIService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AIService>.value(value: ai),
              ChangeNotifierProvider<AuthService>.value(
                value: _FakeAuthService(),
              ),
            ],
            child: MaterialApp(
              key: ValueKey(width),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.6 : 1),
                ),
                child: child!,
              ),
              theme: AppTheme.gamifiedTheme,
              home: const MotchiScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        for (final label in [
          'Pick a movie',
          'Plan a date',
          'Quiz us',
          'Make a game',
        ]) {
          expect(find.widgetWithText(TextButton, label), findsOneWidget);
        }
        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('CAT'), findsNothing);
        expect(find.text('Purring & ready for you two'), findsNothing);
        expect(find.text('Morning recap ☀️'), findsNothing);
        expect(find.byTooltip('Add to message'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is TextField &&
                      widget.decoration?.hintText == 'Message Motchi…',
                ),
              )
              .width,
          lessThanOrEqualTo(720),
        );
        if (width == 320) {
          await tester.tap(find.byTooltip('Add to message'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CheckedPopupMenuItem<String> &&
                  widget.value == 'canvas',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byTooltip('Canvas: on — tap to turn off'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomRight(find.byTooltip('Send message')).dy,
          lessThanOrEqualTo(564),
        );
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpWidget(const SizedBox.shrink());
        ai.dispose();
      }
    },
  );

  testWidgets('tucked-away controls preserve thinking, Canvas, send and stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Browser CI otherwise reports only "See exception logs above".
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrintSynchronously(details.toString());
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    final ai = _InteractionAIService();
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
    await tester.tap(find.text('Auto'));
    await tester.pump();
    expect(find.text('Deep'), findsOneWidget);
    await tester.tap(find.text('Deep'));
    await tester.pump();
    expect(find.text('Fast'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to message'));
    await tester.pumpAndSettle();
    expect(find.text('Attach images'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<String> && widget.value == 'canvas',
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'A quiet evening');
    // Typing schedules the rebuild that enables the Send button.
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single, (
      message: 'A quiet evening',
      thinking: false,
      canvas: true,
    ));
    expect(find.byTooltip('Stop generating'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop generating'));
    await tester.pumpAndSettle();
    expect(ai.isLoading, isFalse);
    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();
    expect(ai.assistantConversation!.messages, isEmpty);
    for (final label in [
      'Pick a movie',
      'Plan a date',
      'Quiz us',
      'Make a game',
    ]) {
      expect(find.widgetWithText(TextButton, label), findsOneWidget);
    }
    await tester.tap(find.byTooltip('History'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Close history'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    ai.dispose();
  });

  testWidgets('welcome rows send their prompts and keep automatic Canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (label, prompt, canvas) in const [
      (
        'Pick a movie',
        'What should we watch tonight from our watchlist?',
        false,
      ),
      ('Plan a date', 'Plan a cozy date night for us', false),
      ('Quiz us', 'Quiz us with 5 fun questions', true),
      ('Make a game', 'Build us a tiny game', true),
    ]) {
      final ai = _InteractionAIService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AIService>.value(value: ai),
            ChangeNotifierProvider<AuthService>.value(
              value: _FakeAuthService(),
            ),
          ],
          child: MaterialApp(
            key: ValueKey(label),
            theme: AppTheme.gamifiedTheme.copyWith(
              visualDensity: VisualDensity.compact,
            ),
            home: const MotchiScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(TextButton, label);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pump();
      expect(ai.requests, hasLength(1));
      expect(ai.requests.single.message, prompt);
      expect(ai.requests.single.canvas, canvas);
      await tester.tap(find.byTooltip('Stop generating'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      ai.dispose();
    }
  });

  testWidgets('more menu keeps every Motchi destination reachable on phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ai = _InteractionAIService();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MotchiScreen()),
        for (final path in ['motchi-memory', 'motchi-trivia', 'motchi-today'])
          GoRoute(
            path: '/$path',
            builder: (_, _) => Scaffold(body: Center(child: Text(path))),
          ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AIService>.value(value: ai),
          ChangeNotifierProvider<AuthService>.value(value: _FakeAuthService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    for (final (label, path) in [
      ('Memory Book', 'motchi-memory'),
      ('Memory Trivia', 'motchi-trivia'),
      ('Motchi Today', 'motchi-today'),
    ]) {
      await tester.tap(find.byTooltip('More from Motchi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    ai.dispose();
  });

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

  testWidgets('a reply in flight keeps a visible, moving answering glow', (
    tester,
  ) async {
    const halo = ValueKey('motchi-answering-halo');
    Color haloAlphaAt(WidgetTester t) {
      final box = t.widget<Container>(find.byKey(halo)).decoration! as BoxDecoration;
      return (box.gradient! as RadialGradient).colors.first;
    }

    final ai = _StreamingAIService(
      memoryRepo: _FakeMemoryRepo(),
      conversationRepo: _FakeConversationRepo(
        AIConversation(
          id: 'assistant',
          feature: 'assistant',
          messages: [AIMessage(role: 'user', content: 'What are the brackets?')],
        ),
      ),
    );
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

    // Before any text: the thinking header still breathes.
    expect(find.byKey(halo), findsOneWidget);
    final beforeText = haloAlphaAt(tester).a;
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      haloAlphaAt(tester).a,
      isNot(closeTo(beforeText, 0.001)),
      reason: 'the halo must animate, not sit still',
    );

    ai.stream('Let me check the bracket draw.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Mid-reply the glow is still there, and the text is never hidden
    // behind an entrance fade that has not run yet.
    expect(find.byKey(halo), findsOneWidget);
    expect(find.textContaining('Let me check the bracket draw.'), findsOneWidget);
    final midway = haloAlphaAt(tester).a;
    await tester.pump(const Duration(milliseconds: 900));
    expect(haloAlphaAt(tester).a, isNot(closeTo(midway, 0.001)));
    expect(tester.takeException(), isNull);

    // The tree comes down before dispose: a disposed notifier must not
    // still have listeners attached.
    await tester.pumpWidget(const SizedBox.shrink());
    ai.dispose();
  });
}
