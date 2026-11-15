import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';

MediaItem _animexItem(int i) {
  return MediaItem(
    id: 'a$i',
    tmdbId: i,
    title: 'Anime Title Number $i',
    mediaType: 'tv',
    posterPath: '',
    backdropPath: '',
    year: '2026',
    status: 'to-watch',
    isAnime: true,
    addedAt: DateTime(2026, 1, 1),
    source: 'jikan',
    synopsis:
        'A long synopsis that wraps across several lines to ensure the '
        'hero layout still fits inside the available space on a phone.',
    episodeCount: 12,
    airingStatus: 'RELEASING',
    format: 'TV',
  );
}

void main() {
  for (final size in [const Size(320, 800), const Size(820, 1180)]) {
    testWidgets('spotlight actions remain reachable with large text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var watched = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimeXSpotlight(
                items: [_animexItem(1)],
                onWatch: (_) => watched = true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Watch Now'));
      await tester.tap(find.text('Watch Now'));
      expect(watched, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('AnimeXSpotlight hero fits viewport on phone with status bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: AnimeXTokens.headerHeight),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: AnimeXSpotlight(
                              items: List.generate(
                                5,
                                (i) => _animexItem(i + 1),
                              ),
                              loading: false,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const SizedBox(
            height: AnimeXTokens.mobileNavHeight,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final hero = tester.getRect(find.byType(AnimeXSpotlight));
    expect(hero.top, 104);
    expect(
      hero.bottom,
      lessThanOrEqualTo(788.1),
      reason:
          'Hero bottom should not be clipped by the viewport. Got: ${hero.bottom}',
    );
  });

  testWidgets('AnimeXSpotlight maintains slide visibility and sync when items update', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1568, 731));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items5 = List.generate(5, (i) => _animexItem(i + 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: items5,
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(AppMotion.carouselHold * 3);
    expect(find.text('#4 TRENDING'), findsOneWidget);

    final items3 = List.generate(3, (i) => _animexItem(i + 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: items3,
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('#1 TRENDING'), findsOneWidget);
  });

  testWidgets('AnimeXSpotlight survives repeated fullscreen toggle cycles without error', (
    WidgetTester tester,
  ) async {
    final items = List.generate(5, (i) => _animexItem(i + 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: items,
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.binding.setSurfaceSize(const Size(1568, 731));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('#1 TRENDING'), findsOneWidget);
  });

  testWidgets('AnimeXSpotlight renders trailer controls and toggles mute and play/pause', (
    WidgetTester tester,
  ) async {
    final itemWithTrailer = MediaItem(
      id: 't1',
      tmdbId: 101,
      title: 'Mushoku Tensei Season 3',
      mediaType: 'tv',
      posterPath: '',
      backdropPath: '',
      year: '2026',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      synopsis: 'The third season of Mushoku Tensei.',
      episodeCount: 14,
      airingStatus: 'RELEASING',
      format: 'TV',
      trailerYoutubeId: 'dQw4w9WgXcQ',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: [itemWithTrailer],
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(TrailerPlayer), findsOneWidget);

    expect(find.byTooltip('Unmute trailer'), findsOneWidget);
    expect(find.byTooltip('Pause trailer'), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute trailer'));
    await tester.pump();

    expect(find.byTooltip('Mute trailer'), findsOneWidget);
    expect(find.byTooltip('Unmute trailer'), findsNothing);

    await tester.tap(find.byTooltip('Mute trailer'));
    await tester.pump();
    expect(find.byTooltip('Unmute trailer'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause trailer'));
    await tester.pump();
    expect(find.byTooltip('Play trailer'), findsOneWidget);

    await tester.tap(find.byTooltip('Play trailer'));
    await tester.pump();
    expect(find.byTooltip('Pause trailer'), findsOneWidget);
  });

  testWidgets('AnimeXSpotlight Trailer action button unmutes hero trailer when muted', (
    WidgetTester tester,
  ) async {
    final itemWithTrailer = MediaItem(
      id: 't2',
      tmdbId: 102,
      title: 'Solo Leveling Season 2',
      mediaType: 'tv',
      posterPath: '',
      backdropPath: '',
      year: '2025',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      synopsis: 'Arise.',
      episodeCount: 12,
      airingStatus: 'FINISHED',
      format: 'TV',
      trailerYoutubeId: 'abc123xyz',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: [itemWithTrailer],
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(TrailerPlayer), findsOneWidget);

    expect(find.byTooltip('Unmute trailer'), findsOneWidget);

    final trailerButton = find.text('Trailer');
    expect(trailerButton, findsOneWidget);
    await tester.tap(trailerButton);
    await tester.pump();

    expect(find.byTooltip('Mute trailer'), findsOneWidget);
  });

  testWidgets('AnimeXSpotlight fades trailer layer in when ready and out when paused', (
    WidgetTester tester,
  ) async {
    final itemWithTrailer = MediaItem(
      id: 't3',
      tmdbId: 103,
      title: 'Frieren Beyond Journeys End',
      mediaType: 'tv',
      posterPath: '',
      backdropPath: '',
      year: '2024',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      synopsis: 'The journey continues.',
      episodeCount: 28,
      airingStatus: 'FINISHED',
      format: 'TV',
      trailerYoutubeId: 'frieren_trailer',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: [itemWithTrailer],
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final trailerLayerFinder = find.byKey(
      const ValueKey('hero-trailer-layer-frieren_trailer'),
    );
    expect(trailerLayerFinder, findsOneWidget);

    final opacityWidget = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(opacityWidget.opacity, 1.0);

    await tester.tap(find.byTooltip('Pause trailer'));
    await tester.pump();
    final pausedOpacity = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(pausedOpacity.opacity, 0.0);

    await tester.tap(find.byTooltip('Play trailer'));
    await tester.pump();
    final resumedOpacity = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(resumedOpacity.opacity, 1.0);
  });

  testWidgets('AnimeXSpotlight holds trailer slides for the full shared hold',
      (
    WidgetTester tester,
  ) async {
    final item1WithTrailer = MediaItem(
      id: 'h1',
      tmdbId: 201,
      title: 'Trailer Anime 1',
      mediaType: 'tv',
      posterPath: '',
      backdropPath: '',
      year: '2025',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      synopsis: 'Trailer anime 1.',
      episodeCount: 12,
      airingStatus: 'FINISHED',
      format: 'TV',
      trailerYoutubeId: 'trailer_key_1',
    );
    final item2 = MediaItem(
      id: 'h2',
      tmdbId: 202,
      title: 'Still Anime 2',
      mediaType: 'tv',
      posterPath: '',
      backdropPath: '',
      year: '2025',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      synopsis: 'Still anime 2.',
      episodeCount: 12,
      airingStatus: 'FINISHED',
      format: 'TV',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AnimeXTokens.bg,
          body: AnimeXSpotlight(
            items: [item1WithTrailer, item2],
            loading: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Trailer Anime 1'), findsOneWidget);

    await tester.pump(AppMotion.carouselHoldTrailer - const Duration(seconds: 1));
    expect(find.text('Trailer Anime 1'), findsOneWidget);
    expect(find.text('Still Anime 2'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Still Anime 2'), findsOneWidget);
  });
}
