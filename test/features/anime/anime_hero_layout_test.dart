import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
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
}
