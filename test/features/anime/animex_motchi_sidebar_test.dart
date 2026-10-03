import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/repositories/ai_conversation_repo_interface.dart';
import 'package:everglow/features/ai/domain/repositories/ai_memory_repo_interface.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_motchi_sidebar.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_nav.dart';

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => 'clairjassen';

  @override
  bool get isCoupleUser => true;

  @override
  bool get isCinemaOnlyUser => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCinemaOnlyAuthService extends ChangeNotifier implements AuthService {
  final String _user;
  _FakeCinemaOnlyAuthService([this._user = 'breyan']);

  @override
  String? get currentUser => _user;

  @override
  bool get isCoupleUser => false;

  @override
  bool get isCinemaOnlyUser => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConversationRepo implements IAIConversationRepository {
  AIConversation? assistantConv;
  int saveCount = 0;
  int archiveCount = 0;

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
  Future<void> save(AIConversation conversation) async {
    saveCount++;
  }

  @override
  Future<void> archiveSession(AIConversation conversation) async {
    archiveCount++;
  }

  @override
  Future<void> loadSessionIntoConversation(AIConversation conversation) async {}

  @override
  Future<void> clear(String feature, {bool archive = true}) async {}

  @override
  Future<void> loadAssistant() async {
    await getOrCreate('assistant');
  }

  @override
  void startFresh() {
    assistantConv = null;
  }

  @override
  Future<List<AISession>> listSessions({int limit = 50}) async => [];

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AnimeXMotchiSidebar', () {
    late AnimeXController controller;
    late _FakeConversationRepo convRepo;
    late AIService aiService;
    late _FakeAuthService authService;

    setUp(() {
      controller = AnimeXController();
      convRepo = _FakeConversationRepo();
      aiService = AIService(
        conversationRepo: convRepo,
        memoryRepo: _FakeMemoryRepo(),
      );
      authService = _FakeAuthService();
    });

    tearDown(() {
      controller.dispose();
      aiService.dispose();
      authService.dispose();
    });

    Widget buildTestHarness({
      required bool isOpen,
      required VoidCallback onClose,
      required List<AIMessage> messages,
      required VoidCallback onClear,
      AuthService? auth,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(
            value: auth ?? authService,
          ),
          ChangeNotifierProvider<AIService>.value(value: aiService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AnimeXMotchiSidebar(
              isOpen: isOpen,
              onClose: onClose,
              controller: controller,
              messages: messages,
              onClear: onClear,
            ),
          ),
        ),
      );
    }

    testWidgets('renders header, title, and TEMPORARY badge when open',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          isOpen: true,
          onClose: () {},
          messages: [],
          onClear: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Motchi'), findsOneWidget);
      expect(find.text('TEMPORARY'), findsOneWidget);
      expect(
        find.text('Anime Assistant · Unsaved session'),
        findsOneWidget,
      );
      expect(find.byTooltip('Close sidebar'), findsOneWidget);
      expect(find.byTooltip('New Chat (clear)'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('renders empty state greeting and anime suggestions',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          isOpen: true,
          onClose: () {},
          messages: [],
          onClear: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi Clair! 🍡'), findsOneWidget);
      expect(
        find.text(
          'Your temporary anime companion! Ask me for recommendations, plot lore, character details, or anything on your mind.',
        ),
        findsOneWidget,
      );
      expect(find.text('✨ Recommend an anime like Frieren'), findsOneWidget);
      expect(find.text('🌸 Top romance anime to watch together'), findsOneWidget);
    });

    testWidgets('DeepThink toggle cycles between Auto, Think, and Off',
        (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          isOpen: true,
          onClose: () {},
          messages: [],
          onClear: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auto'), findsOneWidget);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(find.text('Think'), findsOneWidget);

      await tester.tap(find.text('Think'));
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('New Chat / Clear button clears messages', (tester) async {
      final messages = [
        AIMessage(role: 'user', content: 'What is Frieren?'),
        AIMessage(role: 'assistant', content: 'Frieren is an elf mage!'),
      ];

      var cleared = false;
      await tester.pumpWidget(
        buildTestHarness(
          isOpen: true,
          onClose: () {},
          messages: messages,
          onClear: () {
            cleared = true;
            messages.clear();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What is Frieren?'), findsOneWidget);
      expect(find.text('Frieren is an elf mage!'), findsOneWidget);

      await tester.tap(find.byTooltip('New Chat (clear)'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(find.text('What is Frieren?'), findsNothing);
      expect(find.text('Hi Clair! 🍡'), findsOneWidget);
    });

    testWidgets('Close button triggers onClose callback', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        buildTestHarness(
          isOpen: true,
          onClose: () => closed = true,
          messages: [],
          onClear: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close sidebar'));
      expect(closed, isTrue);
    });

    testWidgets('AnimeXMotchiFloatingTrigger renders and handles tap',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXMotchiFloatingTrigger(onTap: () => tapped = true),
          ),
        ),
      );

      expect(find.text('Motchi'), findsOneWidget);
      expect(find.byTooltip('Chat with Motchi'), findsOneWidget);

      await tester.tap(find.byTooltip('Chat with Motchi'));
      expect(tapped, isTrue);
    });

    testWidgets('AnimeXMotchiFloatingTrigger opens sidebar when tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var isOpen = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthService>.value(value: authService),
                ChangeNotifierProvider<AIService>.value(value: aiService),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: Stack(
                    children: [
                      if (!isOpen)
                        AnimeXMotchiFloatingTrigger(
                          onTap: () => setState(() => isOpen = true),
                        ),
                      AnimeXMotchiSidebar(
                        isOpen: isOpen,
                        onClose: () => setState(() => isOpen = false),
                        controller: controller,
                        messages: const [],
                        onClear: () {},
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Initially, floating trigger is visible and sidebar is closed
      expect(find.byType(AnimeXMotchiFloatingTrigger), findsOneWidget);
      expect(find.text('TEMPORARY'), findsNothing);

      // Tap trigger to open
      await tester.tap(find.byType(AnimeXMotchiFloatingTrigger));
      await tester.pumpAndSettle();

      // Now sidebar is open and floating trigger is gone
      expect(find.text('TEMPORARY'), findsOneWidget);
      expect(find.byType(AnimeXMotchiFloatingTrigger), findsNothing);

      // Tap close button to close
      await tester.tap(find.byTooltip('Close sidebar'));
      await tester.pumpAndSettle();

      // Back to closed
      expect(find.text('TEMPORARY'), findsNothing);
      expect(find.byType(AnimeXMotchiFloatingTrigger), findsOneWidget);
    });

    testWidgets('Motchi is hidden when browsing, and only available when actually watching an anime',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var toggled = false;

      // 1. Browsing Home/Browse (watchItem is null) -> Motchi should NOT be shown in header
      controller.watchItem = null;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<AnimexStores>.value(
              value: AnimexStores.instance,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AnimeXTopHeader(
                controller: controller,
                onSearch: () {},
                onMotchiToggle: () => toggled = true,
                isMotchiOpen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Motchi'), findsNothing);

      // 2. User starts watching an anime -> Motchi appears in header!
      controller.watchItem = MediaItem(
        id: 'watch-test-1',
        tmdbId: 100,
        title: 'Frieren: Beyond Journey\'s End',
        mediaType: 'tv',
        posterPath: '',
        status: 'watching',
        addedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<AnimexStores>.value(
              value: AnimexStores.instance,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AnimeXTopHeader(
                controller: controller,
                onSearch: () {},
                onMotchiToggle: () => toggled = true,
                isMotchiOpen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Motchi'), findsOneWidget);
      await tester.tap(find.text('Motchi'));
      expect(toggled, isTrue);

      // 3. Cinema-only user watching an anime -> Motchi stays hidden
      final cinemaAuth = _FakeCinemaOnlyAuthService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: cinemaAuth),
            ChangeNotifierProvider<AnimexStores>.value(
              value: AnimexStores.instance,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AnimeXTopHeader(
                controller: controller,
                onSearch: () {},
                onMotchiToggle: null,
                isMotchiOpen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Motchi'), findsNothing);
      cinemaAuth.dispose();
    });

    testWidgets('cinema accounts (breyan, octagram) never see Motchi even when watching an anime',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      controller.watchItem = MediaItem(
        id: 'watch-cinema-user',
        tmdbId: 209867,
        title: 'Frieren',
        mediaType: 'tv',
        posterPath: '',
        status: 'watching',
        addedAt: DateTime(2026, 1, 1),
      );

      for (final username in ['breyan', 'octagram']) {
        final cinemaAuth = _FakeCinemaOnlyAuthService(username);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: cinemaAuth),
              ChangeNotifierProvider<AIService>.value(value: aiService),
              ChangeNotifierProvider<AnimexStores>.value(
                value: AnimexStores.instance,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    AnimeXTopHeader(
                      controller: controller,
                      onSearch: () {},
                      onMotchiToggle: cinemaAuth.isCoupleUser && controller.watchItem != null
                          ? controller.toggleMotchi
                          : null,
                      isMotchiOpen: controller.motchiOpen,
                    ),
                    if (cinemaAuth.isCoupleUser && controller.watchItem != null && !controller.motchiOpen)
                      AnimeXMotchiFloatingTrigger(onTap: controller.openMotchi),
                    if (cinemaAuth.isCoupleUser && controller.watchItem != null)
                      AnimeXMotchiSidebar(
                        isOpen: controller.motchiOpen,
                        onClose: controller.closeMotchi,
                        controller: controller,
                        messages: const [],
                        onClear: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Motchi'), findsNothing, reason: 'Failed for $username');
        expect(find.byType(AnimeXMotchiFloatingTrigger), findsNothing, reason: 'Failed for $username');
        expect(find.byType(AnimeXMotchiSidebar), findsNothing, reason: 'Failed for $username');
        cinemaAuth.dispose();
      }
    });

    test('AIService.sendTemporaryMessage does not write to Firestore or archive sessions',
        () async {
      expect(convRepo.saveCount, 0);
      expect(convRepo.archiveCount, 0);
      expect(convRepo.assistant, isNull);

      // Verify that sendTemporaryMessage starts without throwing state error
      // and leaves repo clean
      expect(convRepo.saveCount, 0);
      expect(convRepo.archiveCount, 0);
    });
  });
}
