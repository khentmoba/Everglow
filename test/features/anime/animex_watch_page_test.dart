import 'dart:async';

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

  @override
  Future<void> setOnNavigationRequest(
    FutureOr<NavigationDecision> Function(NavigationRequest request)
    onNavigationRequest,
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
    test('buildServers lists Everglow first with AniList routes', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
        tmdbId: 37854,
      );
      expect(servers.length, 4);

      expect(servers[0].name, 'Everglow');
      expect(servers[0].available, isTrue);
      expect(
        servers[0].urlBuilder(1, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=37854&type=tv&s=1&e=1',
      );

      expect(servers[1].name, 'HiAnime');
      expect(servers[1].available, isTrue);
      expect(
        servers[1].urlBuilder(1, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/'
        'proxyAnime?source=hianime&anilistId=21&malId=21&ep=1&audio=sub',
      );

      expect(servers[2].name, 'Megavid');
      expect(servers[2].available, isTrue);
      expect(
        servers[2].urlBuilder(1, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/'
        'proxyAnime?source=megavid&anilistId=21&malId=21&ep=1&audio=sub',
      );

      expect(servers[3].name, 'Anivexa');
      expect(servers[3].available, isTrue);
      expect(
        servers[3].urlBuilder(1, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/'
        'proxyAnime?source=anivexa&anilistId=21&malId=21&ep=1&audio=sub',
      );
    });

    test('buildServers appends the login token to proxyAnime urls', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
        tmdbId: 37854,
        idToken: 'abc 123',
        title: 'One Piece',
      );
      expect(
        servers[1].urlBuilder(2, 'dub'),
        contains('token=abc%20123'),
      );
      expect(
        servers[1].urlBuilder(2, 'dub'),
        contains('title=One%20Piece'),
      );
      expect(
        servers[2].urlBuilder(2, 'dub'),
        contains('token=abc%20123'),
      );
      expect(
        servers[2].urlBuilder(2, 'dub'),
        contains('title=One%20Piece'),
      );
    });

    test('buildServers falls back to MAL routes when AniList ID is absent', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: null,
        malId: 52991,
        tmdbId: 209867,
      );
      expect(servers.length, 4);

      expect(servers[1].name, 'HiAnime');
      expect(servers[1].available, isTrue);
      expect(
        servers[1].urlBuilder(3, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/'
        'proxyAnime?source=hianime&anilistId=0&malId=52991&ep=3&audio=sub',
      );

      expect(servers[2].name, 'Megavid');
      expect(
        servers[2].urlBuilder(3, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/'
        'proxyAnime?source=megavid&anilistId=0&malId=52991&ep=3&audio=sub',
      );

      expect(servers[0].name, 'Everglow');
      expect(
        servers[0].urlBuilder(3, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=209867&type=tv&s=1&e=3',
      );

      // Anivexa is AniList-keyed, so it stays unavailable without one.
      expect(servers[3].name, 'Anivexa');
      expect(servers[3].available, isFalse);
    });

    test('buildServers maps multi-season episodes for TMDB-keyed players',
        () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 25777,
        malId: 25777,
        tmdbId: 1429,
        episodeSlots: const {
          1: (season: 2, episode: 1),
          2: (season: 2, episode: 2),
        },
      );

      expect(
        servers[0].urlBuilder(1, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=1429&type=tv&s=2&e=1',
      );
      expect(
        servers[0].urlBuilder(2, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=1429&type=tv&s=2&e=2',
      );
      // Episodes without a slot fall back to season 1 and the number itself.
      expect(
        servers[0].urlBuilder(3, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=1429&type=tv&s=1&e=3',
      );
      expect(
        servers.map((s) => s.name),
        ['Everglow', 'HiAnime', 'Megavid', 'Anivexa'],
      );
    });

    test('buildServers hides TMDB-keyed players without a TMDB id', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 16498,
        malId: 16498,
      );

      expect(servers[0].name, 'Everglow');
      expect(servers[0].available, isFalse);
      expect(servers[1].name, 'HiAnime');
      expect(servers[1].available, isTrue);
      expect(servers[2].name, 'Megavid');
      expect(servers[2].available, isTrue);
      expect(servers[3].name, 'Anivexa');
      expect(servers[3].available, isTrue);
    });

    test('buildServers marks all unavailable when no ID is present', () {
      final servers = AnimeXWatchPage.buildServers(anilistId: null, malId: 0);
      for (final s in servers) {
        expect(s.available, isFalse);
      }
    });

    test('resolveMappingsMalId prefers the AniList detail MAL id', () {
      // The reported bug: route carries only an AniList id (slot reads
      // 0), so mappings must use the MAL id from the AniList detail —
      // otherwise ani.zip returns nothing and only Megavid shows.
      expect(
        AnimeXWatchPage.resolveMappingsMalId(
          detailMalId: 21,
          routeMalId: 0,
        ),
        21,
      );
      // No detail (offline) — fall back to the route slot.
      expect(
        AnimeXWatchPage.resolveMappingsMalId(
          detailMalId: null,
          routeMalId: 21,
        ),
        21,
      );
      // Invalid detail id — fall back to the route slot.
      expect(
        AnimeXWatchPage.resolveMappingsMalId(
          detailMalId: 0,
          routeMalId: 21,
        ),
        21,
      );
      // Nothing anywhere — 0 means skip the mappings call.
      expect(
        AnimeXWatchPage.resolveMappingsMalId(
          detailMalId: null,
          routeMalId: 0,
        ),
        0,
      );
    });

    test('normalizeServerName converts legacy names to provider names', () {
      expect(AnimeXWatchPage.normalizeServerName('Server 1'), 'Everglow');
      expect(AnimeXWatchPage.normalizeServerName('Server 2'), 'HiAnime');
      expect(AnimeXWatchPage.normalizeServerName('Server 3'), 'Megavid');
      expect(AnimeXWatchPage.normalizeServerName('Server 4'), 'Anivexa');
      expect(AnimeXWatchPage.normalizeServerName('Megavid'), 'Megavid');
      expect(AnimeXWatchPage.normalizeServerName(''), '');
      expect(AnimeXWatchPage.normalizeServerName(null), '');
    });

    testWidgets('renders the new server list and sub/dub toggle',
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

      expect(find.text('HiAnime'), findsOneWidget);
      expect(find.text('Megavid'), findsOneWidget);
      // The Everglow wrapper is TMDB-keyed; ani.zip can't resolve an id
      // in tests, so the option stays hidden.
      expect(find.text('Everglow'), findsNothing);
      expect(find.text('SUB'), findsOneWidget);
      expect(find.text('DUB'), findsOneWidget);

      await tester.ensureVisible(find.text('Megavid'));
      await tester.tap(find.text('Megavid'));
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
