@TestOn('browser')
library;

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/memory/memory_fact.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_screen.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConversationRepo implements IAIConversationRepository {
  _FakeConversationRepo(this.conversation);

  AIConversation? conversation;
  bool failAssistant = false;
  Completer<void>? assistantGate;

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
  Future<void> loadAssistant() async {
    await assistantGate?.future;
    if (failAssistant) throw StateError('offline');
  }

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
  bool get isAgentSession => false;
  @override
  String? get currentUser => 'clairjassen';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PreviewAuthService extends _FakeAuthService {
  bool loggedOut = false;

  @override
  bool get isAgentSession => true;

  @override
  Future<void> logout() async => loggedOut = true;
}

class _InteractionAIService extends AIService {
  _InteractionAIService()
    : super(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: _FakeConversationRepo(
          AIConversation(id: 'demo', feature: 'assistant'),
        ),
      );

  String reasoning = '';
  @override
  String get draftReasoning => reasoning;

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
    'running actions wrap and thoughts can be collapsed on a small phone',
    (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrintSynchronously(details.toString());
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ai = _InteractionAIService()..loading = true;
      ai.reasoning = 'Synthetic planning notes.';
      ai.draftReasoningNotifier.value = ai.reasoning;
      ai.activeToolsNotifier.value = [
        'search_movies',
        'get_weather',
        'get_date_ideas',
      ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AIService>.value(value: ai),
            ChangeNotifierProvider<AuthService>.value(
              value: _FakeAuthService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const MotchiScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Searching movies…'), findsOneWidget);
      expect(find.text('Checking the weather…'), findsOneWidget);
      expect(
        find.text('Synthetic planning notes.', findRichText: true),
        findsWidgets,
      );
      final toggle = find.widgetWithText(TextButton, "Motchi's thoughts…");
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      final notesBox = tester.renderObject<RenderBox>(
        find
            .ancestor(
              of: find
                  .text('Synthetic planning notes.', findRichText: true)
                  .first,
              matching: find.byType(AnimatedSize),
            )
            .first,
      );
      final expandedHeight = notesBox.size.height;
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(notesBox.size.height, greaterThan(0));
      expect(notesBox.size.height, lessThan(expandedHeight));
      await tester.pump(const Duration(milliseconds: 240));
      expect(notesBox.size.height, 0);
      expect(
        find.text('Synthetic planning notes.', findRichText: true),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      final reducedNotes = find.text(
        'Synthetic planning notes.',
        findRichText: true,
      );
      expect(reducedNotes, findsWidgets);
      expect(
        find.ancestor(
          of: reducedNotes.first,
          matching: find.byType(AnimatedSize),
        ),
        findsNothing,
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(reducedNotes, findsNothing);
      expect(tester.takeException(), isNull);
      ai.reasoning = '';
      ai.draftReasoningNotifier.value = '';
      ai.draftRevisionNotifier.value++;
      await tester.pump();
      expect(find.text('Thinking…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      ai.dispose();
    },
  );

  testWidgets('sources wrap on a small phone and invalid links stay disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.gamifiedTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(
          body: WebSourcesCard(
            sources: [
              {
                'title':
                    'A long synthetic source title that should stay readable on a small phone',
                'url': 'https://example.com/a',
                'site': 'Example',
              },
              {'title': 'Unavailable source', 'url': 'javascript:alert(1)'},
            ],
          ),
        ),
      ),
    );
    final tiles = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
    expect(tiles.first.onTap, isNotNull);
    expect(tiles.last.onTap, isNull);
    expect(
      tester.getSize(find.byType(InkWell).first).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.text('example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview offers real sign-in and returns to Motchi after login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AgentMode.isActive.value = true;
    addTearDown(() => AgentMode.isActive.value = false);
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _PreviewAuthService();
    final ai = _InteractionAIService();
    final router = GoRouter(
      initialLocation: '/motchi?agent=clair',
      routes: [
        GoRoute(path: '/motchi', builder: (_, _) => const MotchiScreen()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Sign-in door')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AIService>.value(value: ai),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: MaterialApp.router(
          theme: AppTheme.gamifiedTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign in to chat'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in door'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      '/motchi',
    );
    expect(AgentMode.isActive.value, isFalse);
    expect(auth.loggedOut, isTrue);
    expect(ai.requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
    ai.dispose();
  });

  testWidgets(
    'quiet welcome and composer fit small phones, tablets and keyboards',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrintSynchronously(details.toString());
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
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
                  widget is PopupMenuItem<String> && widget.value == 'canvas',
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
    await tester.pumpAndSettle();
    expect(find.text('Let Motchi choose how much to think'), findsOneWidget);
    await tester.tap(find.text('Deep'));
    await tester.pumpAndSettle();
    expect(find.text('Deep'), findsOneWidget);
    await tester.tap(find.text('Deep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fast'));
    await tester.pumpAndSettle();
    expect(find.text('Fast'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to message'));
    await tester.pumpAndSettle();
    expect(find.text('Attach images'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == 'canvas',
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

  testWidgets(
    'welcome rows prepare editable prompts and keep automatic Canvas',
    (tester) async {
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
        expect(ai.requests, isEmpty);
        final input = tester.widget<TextField>(find.byType(TextField).first);
        expect(input.controller!.text, prompt);
        expect(input.focusNode!.hasFocus, isTrue);
        await tester.enterText(find.byType(TextField).first, '$prompt, please');
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pump();
        expect(ai.requests, hasLength(1));
        expect(ai.requests.single.message, '$prompt, please');
        expect(ai.requests.single.canvas, canvas);
        await tester.tap(find.byTooltip('Stop generating'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        ai.dispose();
      }
    },
  );

  testWidgets('Enter respects composition and Shift before sending', (
    tester,
  ) async {
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
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'A quiet evening');
    final controller = tester.widget<TextField>(field).controller!;
    controller.value = controller.value.copyWith(
      composing: TextRange(start: 0, end: controller.text.length),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(ai.requests, isEmpty);
    controller.value = controller.value.copyWith(composing: TextRange.empty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(ai.requests, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(ai.requests, hasLength(1));
    await tester.tap(find.byTooltip('Stop generating'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    ai.dispose();
  });

  testWidgets(
    'conversation loading and failure protect the composer until retry',
    (tester) async {
      final repo = _FakeConversationRepo(
        AIConversation(id: 'demo', feature: 'assistant'),
      );
      repo.assistantGate = Completer<void>();
      repo.failAssistant = true;
      final ai = AIService(
        memoryRepo: _FakeMemoryRepo(),
        conversationRepo: repo,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AIService>.value(value: ai),
            ChangeNotifierProvider<AuthService>.value(
              value: _FakeAuthService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: const MotchiScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      repo.assistantGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Your conversation couldn’t load.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      repo.failAssistant = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Your conversation couldn’t load.'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      ai.dispose();
    },
  );

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
      await tester.tap(find.byTooltip('Use as draft'));
      await tester.pump();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Hello Motchi',
      );
      expect(ai.assistantConversation!.messages, hasLength(2));
      expect(find.byTooltip('Copy your message'), findsOneWidget);
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

  for (final width in [430.0, 810.0, 1280.0]) {
    testWidgets('keeps the latest streamed reply in view at ${width.toInt()}px', (
      tester,
    ) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrintSynchronously(details.toString());
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      tester.view.physicalSize = Size(width, 800);
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
            ChangeNotifierProvider<AuthService>.value(
              value: _FakeAuthService(),
            ),
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
      controller.jumpTo(0);
      await tester.pump();
      ai.stream(List.filled(32, 'Another streamed line.').join('\n'));
      await tester.pump();
      expect(controller.position.pixels, 0);
      final latest = find.widgetWithText(FilledButton, 'Latest message');
      expect(tester.getSize(latest).height, greaterThanOrEqualTo(48));
      await tester.tap(latest);
      // The post-frame callback schedules the animation; its first tick starts it.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // Lazy rows can revise the extent after arriving at the estimated bottom.
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump();
      }
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 1),
      );
      expect(find.text('Latest message'), findsNothing);
      ai.stream(List.filled(36, 'The next streamed line.').join('\n'));
      await tester.pump();
      await tester.pump();
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    });
  }

  testWidgets('a reply in flight keeps a visible, moving answering glow', (
    tester,
  ) async {
    const halo = ValueKey('motchi-answering-halo');
    Color haloAlphaAt(WidgetTester t) {
      final box =
          t.widget<Container>(find.byKey(halo)).decoration! as BoxDecoration;
      return (box.gradient! as RadialGradient).colors.first;
    }

    final ai = _StreamingAIService(
      memoryRepo: _FakeMemoryRepo(),
      conversationRepo: _FakeConversationRepo(
        AIConversation(
          id: 'assistant',
          feature: 'assistant',
          messages: [
            AIMessage(role: 'user', content: 'What are the brackets?'),
          ],
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

    // Before any text: the thinking header still breathes and shows thinking badge.
    expect(find.byKey(halo), findsOneWidget);
    expect(find.text('thinking'), findsOneWidget);
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
    // Mid-reply the glow is still there, replying badge shows, and the text
    // is never hidden behind an entrance fade that has not run yet.
    expect(find.byKey(halo), findsOneWidget);
    expect(find.text('replying'), findsOneWidget);
    expect(find.text('thinking'), findsNothing);
    expect(
      find.textContaining('Let me check the bracket draw.'),
      findsOneWidget,
    );
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
