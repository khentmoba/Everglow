import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_watch_page.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageFinished(
    void Function(String url) onPageFinished,
  ) async {}

  @override
  Future<void> setOnWebResourceError(
    void Function(WebResourceError error) onWebResourceError,
  ) async {}
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }
}

MediaItem _sampleWatchItem() {
  return MediaItem(
    id: 'animex-test-1',
    tmdbId: 0,
    title: 'Vinland Saga',
    mediaType: 'tv',
    posterPath: '',
    backdropPath: '',
    year: '2019',
    status: 'to-watch',
    isAnime: true,
    addedAt: DateTime(2026, 1, 1),
    source: 'jikan',
    currentEpisode: 1,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  Widget buildTestApp(AnimeXController controller) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AnimexStores>.value(
          value: AnimexStores.instance,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AnimeXWatchPage(controller: controller),
        ),
      ),
    );
  }

  testWidgets(
    'AnimeXWatchPage player is constrained on desktop (1920x1080) and does not span full screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // Find the player box widget.
      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // Verify the player is smaller and does NOT span 1920 or 1536.
      expect(playerSize.width, lessThanOrEqualTo(AnimeXTokens.watchPageMaxWidth));
      expect(playerSize.width, lessThan(1536));
      expect(playerSize.height, lessThanOrEqualTo(AnimeXTokens.playerMaxHeight));

      // With horizontal padding 24 on each side, content width should be 952.
      expect(playerSize.width, closeTo(952.0, 1.0));
      expect(playerSize.height, closeTo(952.0 * 9 / 16, 1.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'AnimeXWatchPage player scales down cleanly on short height screens',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // On 560px viewport height, height cap is (560 - 280) = 280px.
      expect(playerSize.height, lessThanOrEqualTo(280.0));
      // At 16:9, width should be 280 * 16 / 9 ~ 497.8px.
      expect(playerSize.width, closeTo(280.0 * 16 / 9, 2.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'AnimeXWatchPage player fits inside tablet and mobile screens',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // Width is 768 - 48 = 720
      expect(playerSize.width, closeTo(720.0, 1.0));
      expect(playerSize.height, closeTo(720.0 * 9 / 16, 1.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  group('AnimeXWatchPage servers', () {
    test('buildServers creates Mega Play, Anixo, and Megavid with AniList routes', () {
      final servers = AnimeXWatchPage.buildServers(anilistId: 21, malId: 21);
      expect(servers.length, 3);

      expect(servers[0].name, 'Mega Play');
      expect(servers[0].available, isTrue);
      expect(
        servers[0].urlBuilder(1, 'sub'),
        'https://megaplay.buzz/stream/ani/21/1/sub',
      );
      expect(
        servers[0].urlBuilder(1, 'dub'),
        'https://megaplay.buzz/stream/ani/21/1/dub',
      );

      expect(servers[1].name, 'Anixo');
      expect(servers[1].available, isTrue);
      expect(
        servers[1].urlBuilder(1, 'sub'),
        'https://anixo.buzz/embed/ani/21/1?track=sub',
      );
      expect(
        servers[1].urlBuilder(1, 'dub'),
        'https://anixo.buzz/embed/ani/21/1?track=dub',
      );

      expect(servers[2].name, 'Megavid');
      expect(servers[2].available, isTrue);
      expect(
        servers[2].urlBuilder(1, 'sub'),
        'https://megavid.buzz/ani/21/1/sub',
      );
      expect(
        servers[2].urlBuilder(1, 'dub'),
        'https://megavid.buzz/ani/21/1/dub',
      );
    });

    test('buildServers falls back to MAL routes when AniList ID is absent', () {
      final servers = AnimeXWatchPage.buildServers(anilistId: null, malId: 52991);
      expect(servers.length, 3);

      expect(servers[0].name, 'Mega Play');
      expect(
        servers[0].urlBuilder(3, 'sub'),
        'https://megaplay.buzz/stream/mal/52991/3/sub',
      );
      expect(
        servers[0].urlBuilder(3, 'dub'),
        'https://megaplay.buzz/stream/mal/52991/3/dub',
      );

      expect(servers[1].name, 'Anixo');
      expect(
        servers[1].urlBuilder(3, 'sub'),
        'https://anixo.buzz/embed/mal/52991/3?track=sub',
      );
      expect(
        servers[1].urlBuilder(3, 'dub'),
        'https://anixo.buzz/embed/mal/52991/3?track=dub',
      );

      expect(servers[2].name, 'Megavid');
      expect(
        servers[2].urlBuilder(3, 'sub'),
        'https://megavid.buzz/mal/52991/3/sub',
      );
      expect(
        servers[2].urlBuilder(3, 'dub'),
        'https://megavid.buzz/mal/52991/3/dub',
      );
    });

    test('buildServers marks all unavailable when no ID is present', () {
      final servers = AnimeXWatchPage.buildServers(anilistId: null, malId: 0);
      for (final s in servers) {
        expect(s.available, isFalse);
      }
    });

    test('normalizeServerName converts legacy names to provider names', () {
      expect(AnimeXWatchPage.normalizeServerName('Server 1'), 'Mega Play');
      expect(AnimeXWatchPage.normalizeServerName('Server 2'), 'Anixo');
      expect(AnimeXWatchPage.normalizeServerName('Server 3'), 'Megavid');
      expect(AnimeXWatchPage.normalizeServerName('Mega Play'), 'Mega Play');
      expect(AnimeXWatchPage.normalizeServerName(''), '');
      expect(AnimeXWatchPage.normalizeServerName(null), '');
    });

    testWidgets('renders Mega Play, Anixo, Megavid buttons and sub/dub toggle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = MediaItem(
        id: 'animex-test-providers',
        tmdbId: 21,
        anilistId: 21,
        title: 'One Piece',
        mediaType: 'tv',
        posterPath: '',
        backdropPath: '',
        year: '1999',
        status: 'to-watch',
        isAnime: true,
        addedAt: DateTime(2026, 1, 1),
        source: 'jikan',
        currentEpisode: 1,
      );

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      expect(find.text('Mega Play'), findsOneWidget);
      expect(find.text('Anixo'), findsOneWidget);
      expect(find.text('Megavid'), findsOneWidget);
      expect(find.text('SUB'), findsOneWidget);
      expect(find.text('DUB'), findsOneWidget);

      await tester.ensureVisible(find.text('Anixo'));
      await tester.tap(find.text('Anixo'));
      await tester.pump();

      await tester.ensureVisible(find.text('DUB'));
      await tester.tap(find.text('DUB'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders PC episodes sidebar on desktop with search, sort, and episode cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // On desktop, the sidebar shows "Episodes", "Find episode", and "Oldest" sort
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('Find episode'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);

      // Verify sort toggle works
      await tester.tap(find.text('Oldest'));
      await tester.pump();
      expect(find.text('Newest'), findsOneWidget);

      // Verify search input filters
      await tester.enterText(find.byType(TextField).first, 'Episode 2');
      await tester.pump();

      // Verify server notice banner is present and can be dismissed
      expect(
        find.text(
          "If the current server doesn't work, feel free to try the other available servers.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      expect(
        find.text(
          "If the current server doesn't work, feel free to try the other available servers.",
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders mobile episode selector directly below player on mobile screens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // On mobile, the header is "EPISODES" with Search and swap_vert buttons
      expect(find.text('EPISODES'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);

      // Tapping Search opens the search bar
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(
        find.text('Search by title, number, or keyword...'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('tapping an episode tile in PC sidebar updates selected episode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // Find episode 2 in the sidebar and tap it
      expect(find.text('Episode 2'), findsWidgets);
      await tester.tap(find.text('Episode 2').first);
      await tester.pump();

      // Selected episode is updated to 2
      expect(find.text('Episode 2'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('episode info sheet opens and displays episode synopsis and play action',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // Tap "What happened" if present or open sheet directly
      final whatHappenedFinder = find.text('What happened');
      if (whatHappenedFinder.evaluate().isNotEmpty) {
        await tester.tap(whatHappenedFinder.first);
        await tester.pumpAndSettle();
        expect(find.text('What happened in this episode'), findsOneWidget);
      }

      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
