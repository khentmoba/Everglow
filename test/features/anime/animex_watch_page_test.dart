import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:everglow/features/anime/data/models/anilist_detail.dart';
import 'package:everglow/features/anime/data/services/anilist_service.dart';
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

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}
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
      expect(servers.length, 3);

      expect(servers[0].name, 'Everglow');
      expect(servers[0].available, isTrue);
      expect(
        servers[0].urlBuilder(1, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=37854&type=tv&s=1&e=1',
      );

      // Megavid plays through our ad-free resolver, never the
      // provider's website embed.
      expect(servers[1].name, 'Megavid');
      expect(servers[1].available, isTrue);
      expect(
        servers[1].urlBuilder(1, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime'
        '?source=megavid&anilistId=21&malId=21&ep=1&audio=sub',
      );

      // AniXo was removed: a bot-gated relay over MegaPlay with its own
      // popunder ad tag. MegaPlay stays last as the ad-heavy fallback.
      expect(servers[2].name, 'MegaPlay');
      expect(servers[2].available, isTrue);
      expect(
        servers[2].urlBuilder(1, 'sub'),
        'https://megaplay.buzz/stream/ani/21/1/sub',
      );
    });

    test('buildServers points Megavid at our ad-free resolver', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
        tmdbId: 37854,
      );
      // Episode and dub ride the query string the function validates.
      expect(
        servers[1].urlBuilder(2, 'dub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime'
        '?source=megavid&anilistId=21&malId=21&ep=2&audio=dub',
      );
    });

    test('buildServers falls back to MAL routes when AniList ID is absent', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: null,
        malId: 52991,
        tmdbId: 209867,
      );
      expect(servers.length, 3);

      expect(servers[1].name, 'Megavid');
      expect(
        servers[1].urlBuilder(3, 'sub'),
        'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime'
        '?source=megavid&anilistId=0&malId=52991&ep=3&audio=sub',
      );

      expect(servers[2].name, 'MegaPlay');
      expect(
        servers[2].urlBuilder(3, 'sub'),
        'https://megaplay.buzz/stream/mal/52991/3/sub',
      );

      expect(servers[0].name, 'Everglow');
      expect(
        servers[0].urlBuilder(3, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=209867&type=tv&s=1&e=3',
      );

      // AniList-only routes still get every AniList-keyed server.
      expect(servers[1].available, isTrue);
      expect(servers[1].name, 'Megavid');
      expect(servers[1].available, isTrue);
      expect(servers[2].name, 'MegaPlay');
      expect(servers[2].available, isTrue);
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
        ['Everglow', 'Megavid', 'MegaPlay'],
      );
    });

    test('buildServers hides TMDB-keyed players without a TMDB id', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 16498,
        malId: 16498,
      );

      expect(servers[0].name, 'Everglow');
      expect(servers[0].available, isFalse);
      expect(servers[1].name, 'Megavid');
      expect(servers[1].available, isTrue);
      expect(servers[2].name, 'MegaPlay');
      expect(servers[2].available, isTrue);
    });

    test('buildServers marks all unavailable when no ID is present', () {
      final servers = AnimeXWatchPage.buildServers(anilistId: null, malId: 0);
      for (final s in servers) {
        expect(s.available, isFalse);
      }
    });

    test('buildServers uses the movie endpoint for films', () {
      // Drifting Home: ani.zip has no TMDB id and its film id only
      // plays through the movie endpoint — the TV endpoint opens nothing.
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 139643,
        malId: 49938,
        tmdbId: 877957,
        isMovie: true,
      );
      expect(servers.length, 3);
      expect(servers[0].name, 'Everglow');
      expect(servers[0].available, isTrue);
      expect(
        servers[0].urlBuilder(1, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=877957&type=movie',
      );
      // Series keep the season/episode TV endpoint by default.
      final series = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
        tmdbId: 37854,
      );
      expect(
        series[0].urlBuilder(1, 'sub'),
        'https://everglow-1c6db.web.app/embed.html'
        '?tmdbId=37854&type=tv&s=1&e=1',
      );
    });

    group('pickTmdbFallbackId', () {
      MediaItem result({
        required int id,
        required String title,
        required String type,
        required String year,
      }) {
        return MediaItem(
          id: 'tmdb-fallback-test',
          tmdbId: id,
          title: title,
          mediaType: type,
          posterPath: '',
          backdropPath: '',
          year: year,
          status: '',
          isAnime: false,
          addedAt: DateTime(2026, 1, 1),
          source: 'tmdb',
        );
      }

      test('picks the strict movie match', () {
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 111,
                title: 'Drifting Home: Drift Away',
                type: 'movie',
                year: '2022',
              ),
              result(
                id: 877957,
                title: 'Drifting Home',
                type: 'movie',
                year: '2022',
              ),
            ],
            title: 'Drifting Home',
            year: '2022',
            isMovie: true,
          ),
          877957,
        );
      });

      test('rejects year, kind, and title mismatches', () {
        // Wrong year.
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 1,
                title: 'Drifting Home',
                type: 'movie',
                year: '2024',
              ),
            ],
            title: 'Drifting Home',
            year: '2022',
            isMovie: true,
          ),
          isNull,
        );
        // TV entry for a film.
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 2,
                title: 'Drifting Home',
                type: 'tv',
                year: '2022',
              ),
            ],
            title: 'Drifting Home',
            year: '2022',
            isMovie: true,
          ),
          isNull,
        );
        // Near-miss title and empty inputs never guess.
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 3,
                title: 'Drifting Homes',
                type: 'movie',
                year: '2022',
              ),
            ],
            title: 'Drifting Home',
            year: '2022',
            isMovie: true,
          ),
          isNull,
        );
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [],
            title: 'Drifting Home',
            year: '2022',
            isMovie: true,
          ),
          isNull,
        );
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 4,
                title: 'Drifting Home',
                type: 'movie',
                year: '2022',
              ),
            ],
            title: '',
            year: '2022',
            isMovie: true,
          ),
          isNull,
        );
      });

      test('picks series through the tv kind', () {
        expect(
          AnimeXWatchPage.pickTmdbFallbackId(
            results: [
              result(
                id: 37854,
                title: 'One Piece',
                type: 'tv',
                year: '1999',
              ),
            ],
            title: 'One Piece',
            year: '1999',
            isMovie: false,
          ),
          37854,
        );
      });
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

    test('defaultServerIndex keeps Everglow as the main server', () {
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
        tmdbId: 37854,
      );
      // Fresh visits open on Everglow even though MegaPlay sits at the
      // stale pre-load index — this used to stick Clair on MegaPlay.
      expect(
        AnimeXWatchPage.defaultServerIndex(servers),
        0,
      );
      // An explicit remembered choice still wins.
      expect(
        AnimeXWatchPage.defaultServerIndex(
          servers,
          rememberedServer: 'MegaPlay',
        ),
        2,
      );
      // A remembered server that no longer exists (AniXo, VidLink)
      // falls back to Everglow, never to a dead entry.
      expect(
        AnimeXWatchPage.defaultServerIndex(
          servers,
          rememberedServer: 'AniXo',
        ),
        0,
      );
      // Without a TMDB mapping Everglow hides, so fresh visits open
      // on the ad-free Megavid resolver instead of MegaPlay.
      final noTmdb = AnimeXWatchPage.buildServers(
        anilistId: 21,
        malId: 21,
      );
      expect(
        AnimeXWatchPage.defaultServerIndex(noTmdb),
        1,
      );
      expect(noTmdb[1].name, 'Megavid');
      // Nothing available yet — index 0 until _load resolves.
      final none = AnimeXWatchPage.buildServers(
        anilistId: null,
        malId: 0,
      );
      expect(AnimeXWatchPage.defaultServerIndex(none), 0);
    });

    test('mapPlayerEpisodeToMal maps plain 1:1 shows straight across', () {
      // The reported bug: CineSrc auto-played 1 -> 2 inside the frame while
      // the list still highlighted episode 1. The player reports TMDB S/E;
      // plain shows map season 1 straight to our episode numbers.
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 2,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        2,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 12,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        12,
      );
      // A jump into another season belongs to another catalog entry —
      // never guess, or history and the highlight rewind to episode 1.
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 2,
          tmdbEpisode: 1,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        isNull,
      );
      // Out-of-range and empty inputs never map.
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 13,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        isNull,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 0,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        isNull,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 0,
          tmdbEpisode: 1,
          episodeSlots: const {},
          episodeCount: 12,
        ),
        isNull,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 1,
          episodeSlots: const {},
          episodeCount: 0,
        ),
        isNull,
      );
    });

    test('mapPlayerEpisodeToMal resolves mid-series entries via slots', () {
      // Attack on Titan season 2 style: MAL episodes 1..2 play as
      // TMDB S2E1..2 — the reverse table must land back on MAL numbers.
      const slots = {
        1: (season: 2, episode: 1),
        2: (season: 2, episode: 2),
      };
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 2,
          tmdbEpisode: 1,
          episodeSlots: slots,
          episodeCount: 12,
        ),
        1,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 2,
          tmdbEpisode: 2,
          episodeSlots: slots,
          episodeCount: 12,
        ),
        2,
      );
      // Episodes with no slot (unmapped tail, other seasons) never guess.
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 2,
          tmdbEpisode: 3,
          episodeSlots: slots,
          episodeCount: 12,
        ),
        isNull,
      );
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 1,
          episodeSlots: slots,
          episodeCount: 12,
        ),
        isNull,
      );
      // A slot pointing outside our episode list is corrupt — ignore it.
      expect(
        AnimeXWatchPage.mapPlayerEpisodeToMal(
          tmdbSeason: 1,
          tmdbEpisode: 1,
          episodeSlots: const {99: (season: 1, episode: 1)},
          episodeCount: 12,
        ),
        isNull,
      );
    });

    test('normalizeServerName converts legacy names to provider names', () {
      expect(AnimeXWatchPage.normalizeServerName('Server 1'), 'Everglow');
      // Server 2 (VidLink) was removed, but old saved choices still
      // normalize here and fall back to the first available server.
      expect(AnimeXWatchPage.normalizeServerName('Server 2'), 'VidLink');
      expect(AnimeXWatchPage.normalizeServerName('Server 3'), 'Megavid');
      // Prior spellings map forward so remembered choices survive.
      expect(AnimeXWatchPage.normalizeServerName('Mega Play'), 'MegaPlay');
      expect(AnimeXWatchPage.normalizeServerName('Anixo'), 'AniXo');
      // Server 4 (Anivexa) was removed — the legacy name stays unmapped
      // so an old saved preference renders as its raw string, never as
      // a server that no longer exists.
      expect(AnimeXWatchPage.normalizeServerName('Server 4'), 'Server 4');
      expect(AnimeXWatchPage.normalizeServerName('Megavid'), 'Megavid');
      expect(AnimeXWatchPage.normalizeServerName(''), '');
      expect(AnimeXWatchPage.normalizeServerName(null), '');
    });

    test('isProviderErrorPage matches every known dead-embed page', () {
      // VidLink 404s its anime embeds with a Next.js not-found shell.
      const vidLink404 =
          '<!DOCTYPE html><html lang="en" class="dark"><head>'
          '<title>404: This page could not be found.</title></head>'
          '<body><script>self.__next_f.push("notFound")</script></body>'
          '</html>';
      expect(AnimeXWatchPage.isProviderErrorPage(vidLink404), isTrue);
      // ...and once its bundle runs, the visible card text (with the
      // site's own "coudn't" typo) is the marker.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          "We Coudn't Find This Episode — Please Check back another time",
        ),
        isTrue,
      );
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          "We Couldn't Find This Episode",
        ),
        isTrue,
      );
      // MegaPlay's real 410 page (HTTP 200 with the error text, so the
      // status check can't catch it — the title and code must).
      const megaPlay410 =
          '<title>Error - MegaPlay</title>'
          "<h2>We're Sorry!</h2>"
          '<p>removed due a copyright violation.</p>'
          '<p>Error Code: <span>410</span></p>';
      expect(AnimeXWatchPage.isProviderErrorPage(megaPlay410), isTrue);
      // AniXo's firewall 403 page (title + leech cards).
      const anixo403 =
          '<title>403 Forbidden - Leech Protection Engaged</title>'
          '<h2>403 Leech Block Engaged</h2>';
      expect(AnimeXWatchPage.isProviderErrorPage(anixo403), isTrue);
      // Our own failure pages carry the failover marker.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          'no playable stream sources — try another server.',
        ),
        isTrue,
      );
    });

    test('isProviderErrorPage passes healthy embeds and our own player', () {
      // Our Megavid/AnimePahe player page must never read as dead — the
      // in-player stall card deliberately avoids the failover markers.
      const healthyPlayer =
          '<!DOCTYPE html><html><head><title>Episode 1</title></head>'
          '<body><video id="v" controls playsinline autoplay></video>'
          '<div class="ov" id="boot"></div>'
          '<div class="ov" id="dead" hidden>'
          '<p>This stream stalled.</p><button>Retry</button></div>'
          '<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>'
          '</body></html>';
      expect(AnimeXWatchPage.isProviderErrorPage(healthyPlayer), isFalse);
      // A healthy VidLink embed page.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          '<title>VidLink</title><div id="player"></div>',
        ),
        isFalse,
      );
      // Empty body (proxy failure) is ambiguous, not an error page.
      expect(AnimeXWatchPage.isProviderErrorPage(''), isFalse);
      // Megavid's healthy player page carries the same Embed Only text
      // as its 403 block page (a hidden div) — the probe tells them
      // apart by status code, never by body text.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          '<h2>Embed Only</h2><div id="player"></div>',
        ),
        isFalse,
      );
      // Megavid's healthy page also hides a We're Sorry error template
      // (shown only when its own stream fails at runtime) — the sorry
      // text alone must never read as dead.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          "<title>KissKH Player</title><h2>We're Sorry!</h2>"
          '<p id="error-msg">We can not find the file.</p>',
        ),
        isFalse,
      );
      // AniXo's healthy page hides its sandbox overlay markup plus an
      // all-stream-servers toast string — both must pass, since the
      // frame embeds AniXo unsandboxed and the overlay never shows.
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          '<div class="cp-sandbox-msg">please remove sandbox from '
          'embed code. sandbox is not allowed.</div>',
        ),
        isFalse,
      );
      expect(
        AnimeXWatchPage.isProviderErrorPage(
          "showToast('all stream servers failed: ' + errorMsg)",
        ),
        isFalse,
      );
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

      // VidLink and AniXo were removed: VidLink 404s sitewide since
      // Sep 2026, and AniXo is a bot-gated relay over MegaPlay.
      expect(find.text('VidLink'), findsNothing);
      expect(find.text('AniXo'), findsNothing);
      // No TMDB mapping resolves in tests, so Everglow hides and the
      // visible row matches the Megavid / MegaPlay order.
      expect(find.text('Megavid'), findsOneWidget);
      expect(find.text('MegaPlay'), findsOneWidget);
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

      // Verify server notice banner is removed
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

    test('AniListService.mapSeasonsForTesting discovers seasons, excludes novels/manga, and sorts chronologically', () {
      final mockData = {
        'id': 108465,
        'idMal': 39535,
        'title': {'english': 'Mushoku Tensei: Jobless Reincarnation', 'romaji': 'Mushoku Tensei'},
        'format': 'TV',
        'seasonYear': 2021,
        'startDate': {'year': 2021, 'month': 1, 'day': 11},
        'episodes': 11,
        'coverImage': {'large': 'https://cover/s1.jpg'},
        'relations': {
          'edges': [
            {
              'relationType': 'ADAPTATION',
              'node': {
                'id': 85470,
                'idMal': 70261,
                'title': {'english': 'Mushoku Tensei Novel'},
                'format': 'NOVEL',
                'type': 'MANGA',
                'relations': {
                  'edges': [
                    {
                      'relationType': 'ADAPTATION',
                      'node': {
                        'id': 146065,
                        'idMal': 51179,
                        'title': {'english': 'Mushoku Tensei: Jobless Reincarnation Season 2'},
                        'format': 'TV',
                        'type': 'ANIME',
                        'startDate': {'year': 2023, 'month': 7, 'day': 3},
                        'episodes': 13,
                        'coverImage': {'large': 'https://cover/s2.jpg'},
                      },
                    },
                    {
                      'relationType': 'ALTERNATIVE',
                      'node': {
                        'id': 85564,
                        'title': {'english': 'Mushoku Tensei Manga'},
                        'format': 'MANGA',
                        'type': 'MANGA',
                      },
                    },
                  ],
                },
              },
            },
            {
              'relationType': 'SEQUEL',
              'node': {
                'id': 127720,
                'idMal': 45576,
                'title': {'english': 'Mushoku Tensei: Jobless Reincarnation Cour 2'},
                'format': 'TV',
                'type': 'ANIME',
                'startDate': {'year': 2021, 'month': 10, 'day': 4},
                'episodes': 12,
                'coverImage': {'large': 'https://cover/cour2.jpg'},
              },
            },
          ],
        },
      };

      final seasons = AniListService.mapSeasonsForTesting(mockData);

      expect(seasons.length, 3);
      expect(seasons[0].id, 108465);
      expect(seasons[0].isCurrent, isTrue);
      expect(seasons[0].title, 'Mushoku Tensei: Jobless Reincarnation');
      expect(seasons[0].label, 'Season 1');
      expect(seasons[0].year, 2021);
      expect(seasons[0].episodeCount, 11);

      expect(seasons[1].id, 127720);
      expect(seasons[1].isCurrent, isFalse);
      expect(seasons[1].title, 'Mushoku Tensei: Jobless Reincarnation Cour 2');
      expect(seasons[1].label, 'Season 1 Part 2');
      expect(seasons[1].year, 2021);
      expect(seasons[1].episodeCount, 12);

      expect(seasons[2].id, 146065);
      expect(seasons[2].isCurrent, isFalse);
      expect(seasons[2].title, 'Mushoku Tensei: Jobless Reincarnation Season 2');
      expect(seasons[2].label, 'Season 2');
      expect(seasons[2].year, 2023);
      expect(seasons[2].episodeCount, 13);
    });

    test('AniListService.assignSeasonLabels generates clean concise labels for seasons, parts, OVAs, ONAs, and movies', () {
      final input = [
        const AniListSeason(
          id: 108465,
          title: 'Mushoku Tensei: Jobless Reincarnation',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 127720,
          title: 'Mushoku Tensei: Jobless Reincarnation Cour 2',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 141534,
          title: 'Mushoku Tensei: Jobless Reincarnation Cour 2 - Eris the Goblin Slayer',
          coverImageUrl: '',
          format: 'SPECIAL',
        ),
        const AniListSeason(
          id: 146065,
          title: 'Mushoku Tensei: Jobless Reincarnation Season 2',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 166873,
          title: 'Mushoku Tensei: Jobless Reincarnation Season 2 Part 2',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 178789,
          title: 'Mushoku Tensei: Jobless Reincarnation Season 3',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 217434,
          title: 'Mushoku Tensei III: Isekai Ittara Honki Dasu Part 2',
          coverImageUrl: '',
          format: 'TV',
        ),
      ];

      final labeled = AniListService.assignSeasonLabels(input);

      expect(labeled[0].label, 'Season 1');
      expect(labeled[1].label, 'Season 1 Part 2');
      expect(labeled[2].label, 'Special');
      expect(labeled[3].label, 'Season 2');
      expect(labeled[4].label, 'Season 2 Part 2');
      expect(labeled[5].label, 'Season 3');
      expect(labeled[6].label, 'Season 3 Part 2');
    });

    test('AniListService.assignSeasonLabels numbers multiple OVAs, ONAs, and Movies', () {
      final input = [
        const AniListSeason(
          id: 1,
          title: 'Anime Season 1',
          coverImageUrl: '',
          format: 'TV',
        ),
        const AniListSeason(
          id: 2,
          title: 'Anime: The First OVA',
          coverImageUrl: '',
          format: 'OVA',
        ),
        const AniListSeason(
          id: 3,
          title: 'Anime: The Second OVA',
          coverImageUrl: '',
          format: 'OVA',
        ),
        const AniListSeason(
          id: 4,
          title: 'Anime The Movie',
          coverImageUrl: '',
          format: 'MOVIE',
        ),
        const AniListSeason(
          id: 5,
          title: 'Anime The Movie 2',
          coverImageUrl: '',
          format: 'MOVIE',
        ),
        const AniListSeason(
          id: 6,
          title: 'Anime Net Animation',
          coverImageUrl: '',
          format: 'ONA',
        ),
      ];

      final labeled = AniListService.assignSeasonLabels(input);

      expect(labeled[0].label, 'Season 1');
      expect(labeled[1].label, 'OVA 1');
      expect(labeled[2].label, 'OVA 2');
      expect(labeled[3].label, 'Movie 1');
      expect(labeled[4].label, 'Movie 2');
      expect(labeled[5].label, 'ONA');
    });

    testWidgets('desktop episodes sidebar shows season dropdown and allows selecting another season',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final episodes = [
        const AniListEpisode(number: 1, title: 'Episode 1'),
        const AniListEpisode(number: 2, title: 'Episode 2'),
      ];
      final seasons = [
        const AniListSeason(
          id: 108465,
          malId: 39535,
          title: 'Mushoku Tensei: Jobless Reincarnation',
          label: 'Season 1',
          coverImageUrl: '',
          format: 'TV',
          year: 2021,
          episodeCount: 11,
          isCurrent: true,
        ),
        const AniListSeason(
          id: 146065,
          malId: 51179,
          title: 'Mushoku Tensei: Jobless Reincarnation Season 2',
          label: 'Season 2',
          coverImageUrl: '',
          format: 'TV',
          year: 2023,
          episodeCount: 13,
          isCurrent: false,
        ),
      ];

      AniListSeason? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 380,
              height: 600,
              child: buildDesktopEpisodesSidebarForTesting(
                episodes: episodes,
                selectedEpisode: 1,
                animeTitle: 'Mushoku Tensei',
                fallbackPoster: '',
                onSelectEpisode: (_) {},
                onShowInfo: (_) {},
                seasons: seasons,
                onSelectSeason: (s) => selected = s,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Season 1'), findsOneWidget);
      expect(find.byTooltip('Change Season'), findsOneWidget);

      await tester.tap(find.byTooltip('Change Season'));
      await tester.pumpAndSettle();

      expect(find.text('Season 2'), findsOneWidget);

      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();

      expect(selected?.id, 146065);
    });

    testWidgets('desktop sidebar shows Next Season in Up Next when on last episode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final episodes = [
        const AniListEpisode(number: 1, title: 'Episode 1'),
        const AniListEpisode(number: 2, title: 'Season Finale'),
      ];
      const nextSeason = AniListSeason(
        id: 146065,
        malId: 51179,
        title: 'Season 2',
        coverImageUrl: '',
        format: 'TV',
        year: 2023,
        episodeCount: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 380,
              height: 600,
              child: buildDesktopEpisodesSidebarForTesting(
                episodes: episodes,
                selectedEpisode: 2,
                animeTitle: 'Mushoku Tensei',
                fallbackPoster: '',
                onSelectEpisode: (_) {},
                onShowInfo: (_) {},
                seasons: const [],
                nextSeason: nextSeason,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Up next: Season 2 (Episode 1)'), findsOneWidget);
    });

    testWidgets('mobile episodes section renders Season button when multiple seasons exist',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final episodes = [
        const AniListEpisode(number: 1, title: 'Episode 1'),
      ];
      final seasons = [
        const AniListSeason(
          id: 1,
          title: 'Season 1',
          coverImageUrl: '',
          format: 'TV',
          isCurrent: true,
        ),
        const AniListSeason(
          id: 2,
          title: 'Season 2',
          coverImageUrl: '',
          format: 'TV',
          isCurrent: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildMobileEpisodesSectionForTesting(
              episodes: episodes,
              selectedEpisode: 1,
              animeTitle: 'Anime',
              fallbackPoster: '',
              onSelectEpisode: (_) {},
              onShowInfo: (_) {},
              seasons: seasons,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Season'), findsOneWidget);
      await tester.tap(find.text('Season'));
      await tester.pumpAndSettle();

      expect(find.text('Select Season'), findsOneWidget);
      expect(find.text('Season 2'), findsWidgets);
    });

    test(
      'buildEpisodeList bounds a polluted streaming feed and uses season titles',
      () {
        final detail = AniListDetail(
          id: 108465,
          malId: 39535,
          titleEnglish: 'Mushoku Tensei',
          titleRomaji: 'Mushoku Tensei',
          titleNative: '無職転生',
          synopsis: '',
          coverImageUrl: '',
          bannerImageUrl: '',
          airingStatus: 'FINISHED',
          format: 'TV',
          episodeCount: 11,
          episodes: List.generate(
            24,
            (i) => AniListEpisode(number: i + 1, title: 'Wrong feed ${i + 1}'),
          ),
        );
        final result = AnimeXWatchPage.buildEpisodeList(
          detail: detail,
          aniZipEpisodes: {
            1: {
              'title': {'en': 'Jobless Reincarnation'},
              'image': 's1e1.jpg',
            },
            11: {
              'title': {'en': 'Children and Warriors'},
            },
            12: {
              'title': {'en': 'I Want to Tell You'},
            },
          },
        );

        expect(result, hasLength(11));
        expect(result.first.title, 'Jobless Reincarnation');
        expect(result.first.thumbnail, 's1e1.jpg');
        expect(result.last.title, 'Children and Warriors');
        expect(
          result.any((episode) => episode.title == 'I Want to Tell You'),
          isFalse,
        );
      },
    );

    test(
      'AniListService.mapEpisodesForTesting caps known counts but retains unknown feeds',
      () {
        // AniList's real feed is descending, has no number field, and includes
        // Season 2 titles on this 11-episode Season 1 entry.
        final streaming = List.generate(
          24,
          (i) => {'title': 'Episode ${24 - i} - Later-season title'},
        );
        expect(
          AniListService.mapEpisodesForTesting(streaming, episodeCount: 11),
          hasLength(11),
        );
        expect(AniListService.mapEpisodesForTesting(streaming), hasLength(24));
        expect(
          AniListService.mapEpisodesForTesting(streaming, episodeCount: 0),
          hasLength(24),
        );
      },
    );

    test('split cour continues with its own catalog id and local episodes', () {
      final episodes = AnimeXWatchPage.buildEpisodeList(
        fallbackEpisodeCount: 12,
        aniZipEpisodes: {
          1: {
            'title': {'en': 'The Woman with the Demon Eyes'},
          },
          12: {
            'title': {'en': 'Wake Up and Take a Step'},
          },
          24: {
            'title': {'en': 'Stray feed entry'},
          },
        },
      );
      expect(episodes, hasLength(12));
      expect(episodes.first.title, 'The Woman with the Demon Eyes');
      expect(episodes.last.title, 'Wake Up and Take a Step');
      final servers = AnimeXWatchPage.buildServers(
        anilistId: 127720,
        malId: 45576,
        tmdbId: 94664,
        episodeSlots: {1: (season: 1, episode: 12)},
      );
      expect(
        servers.last.urlBuilder(1, 'sub'),
        'https://megaplay.buzz/stream/ani/127720/1/sub',
      );
      expect(servers.first.urlBuilder(1, 'sub'), contains('&s=1&e=12'));
    });

    test('episode list keeps unknown counts and fills missing metadata', () {
      final episodes = AnimeXWatchPage.buildEpisodeList(
        aniZipEpisodes: {
          3: {
            'title': {'en': 'Third episode'},
          },
        },
      );
      expect(episodes, hasLength(3));
      expect(episodes.first.title, 'Episode 1');
      expect(episodes.last.title, 'Third episode');
      expect(
        AnimeXWatchPage.buildEpisodeList(fallbackEpisodeCount: 2),
        hasLength(2),
      );
    });
  });
}
