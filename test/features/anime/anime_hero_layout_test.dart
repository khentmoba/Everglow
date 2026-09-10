import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_spotlight.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';
import 'package:everglow/shared/widgets/shelf/anime_hero_banner.dart';
import 'package:everglow/shared/widgets/shelf/shelf_hero_carousel.dart';

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
    // Hero must start right below header (44 status + 60 header = 104) and
    // must not extend past the visible body area (ends at 844 - 56 nav = 788).
    expect(hero.top, 104);
    expect(
      hero.bottom,
      lessThanOrEqualTo(788.1),
      reason:
          'Hero bottom should not be clipped by the viewport. Got: ${hero.bottom}',
    );
  });

  testWidgets('AnimeHeroBanner has no overflow on a 360px phone', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = List.generate(3, (i) {
      return ShelfHeroItem(
        id: 'x$i',
        title: 'Hero Title Number $i that is quite long',
        subtitle: '2026',
        imageUrl: '',
        posterUrl: '',
        synopsis:
            'A fairly long synopsis that will wrap across several lines '
            'on a small phone screen and used to overflow the action buttons.',
        episodeCount: 24,
        format: 'TV',
        airingStatus: 'Airing',
        year: '2026',
        onTap: () {},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeHeroBanner(
            items: items,
            holdDuration: const Duration(seconds: 2),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimeHeroBanner has no overflow on desktop with long content', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = List.generate(3, (i) {
      return ShelfHeroItem(
        id: 'x$i',
        title:
            'A Very Long Anime Hero Title That Wraps Across Two Lines '
            'On The Desktop Banner',
        subtitle: '2026',
        imageUrl: '',
        posterUrl: '',
        synopsis:
            'A long synopsis for the hero banner slide that is '
            'deliberately quite long so it wraps across multiple lines and '
            'exercises the bottom-anchored metadata and action button layout '
            'on a wide desktop screen without causing vertical overflow.',
        episodeCount: 24,
        format: 'TV',
        airingStatus: 'Airing',
        year: '2026',
        onTap: () {},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeHeroBanner(
            items: items,
            holdDuration: const Duration(seconds: 2),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
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

    // Advance time to item 4 (_index = 3)
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('#4 TRENDING'), findsOneWidget);

    // Update with fewer items (e.g. 3 items)
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

    // Exactly one slide layer should be visible (opacity > 0)
    final opacities = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
    final visibleCount = opacities.where((op) => op.opacity > 0).length;
    expect(visibleCount, 1, reason: 'Active slide layer must be visible, never 0');
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

    // Simulate toggling fullscreen and unfullscreen repeatedly
    for (var i = 0; i < 5; i++) {
      // Enter fullscreen (1920x1080)
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pump(const Duration(milliseconds: 50));

      // Exit fullscreen (1568x731)
      await tester.binding.setSurfaceSize(const Size(1568, 731));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    final opacities = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
    final visibleCount = opacities.where((op) => op.opacity > 0).length;
    expect(visibleCount, 1, reason: 'Active slide must stay visible after repeated toggles');
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

    // Dwell for 900ms to allow trailer arming
    await tester.pump(const Duration(milliseconds: 900));

    // Trailer player should be mounted and ready
    expect(find.byType(TrailerPlayer), findsOneWidget);

    // Initially muted: unmute tooltip should be visible on the mute control
    expect(find.byTooltip('Unmute trailer'), findsOneWidget);
    expect(find.byTooltip('Pause trailer'), findsOneWidget);

    // Tap mute button to unmute
    await tester.tap(find.byTooltip('Unmute trailer'));
    await tester.pump();

    // Now unmuted: mute tooltip should be visible
    expect(find.byTooltip('Mute trailer'), findsOneWidget);
    expect(find.byTooltip('Unmute trailer'), findsNothing);

    // Tap volume button to mute again
    await tester.tap(find.byTooltip('Mute trailer'));
    await tester.pump();
    expect(find.byTooltip('Unmute trailer'), findsOneWidget);

    // Tap pause button to pause
    await tester.tap(find.byTooltip('Pause trailer'));
    await tester.pump();
    expect(find.byTooltip('Play trailer'), findsOneWidget);

    // Tap play button to resume
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

    // Trailer player should be mounted
    expect(find.byType(TrailerPlayer), findsOneWidget);

    // Initially muted
    expect(find.byTooltip('Unmute trailer'), findsOneWidget);

    // Tap the Trailer button in the hero content
    final trailerButton = find.text('Trailer');
    expect(trailerButton, findsOneWidget);
    await tester.tap(trailerButton);
    await tester.pump();

    // Should now be unmuted
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

    // Before dwell, trailer is not yet armed
    expect(
      find.byKey(const ValueKey('hero-trailer-layer-frieren_trailer')),
      findsNothing,
    );

    // After 900ms, trailer arms and is ready
    await tester.pump(const Duration(milliseconds: 900));
    final trailerLayerFinder = find.byKey(
      const ValueKey('hero-trailer-layer-frieren_trailer'),
    );
    expect(trailerLayerFinder, findsOneWidget);

    final opacityWidget = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(opacityWidget.opacity, 1.0);

    // Tap pause
    await tester.tap(find.byTooltip('Pause trailer'));
    await tester.pump();
    final pausedOpacity = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(pausedOpacity.opacity, 0.0);

    // Tap play
    await tester.tap(find.byTooltip('Play trailer'));
    await tester.pump();
    final resumedOpacity = tester.widget<AnimatedOpacity>(trailerLayerFinder);
    expect(resumedOpacity.opacity, 1.0);
  });
}
