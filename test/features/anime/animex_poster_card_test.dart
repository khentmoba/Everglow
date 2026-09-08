import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_card.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';

MediaItem _sampleItem() {
  return MediaItem(
    id: 'anime-1',
    tmdbId: 0,
    title: 'I Want to Love You Till Your Dying Day',
    mediaType: 'tv',
    posterPath: '',
    year: '2026',
    status: 'to-watch',
    isAnime: true,
    addedAt: DateTime(2026, 1, 1),
    source: 'jikan',
    synopsis:
        'At the mysterious orphanage where Sheena lives, death is '
        'nothing new to its residents. Everyone, that is, except Sheena, who '
        'wishes for her roommate to live. When she wishes for her roommate\'s '
        'death, she meets a strange girl covered in blood who smiles despite '
        'the turmoil surrounding them.',
    episodeCount: 13,
    airingStatus: 'RELEASING',
    format: 'TV',
    genres: const ['Drama', 'Fantasy', 'Romance', 'Supernatural'],
  );
}

void main() {
  testWidgets('hover popover stays compact and shows real details', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AnimeXPosterCard(
                  item: _sampleItem(),
                  width: 175,
                  score: 8.7,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(AnimeXPosterCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final synopsisFinder = find.textContaining('mysterious orphanage');
    expect(synopsisFinder, findsOneWidget);

    final popoverBox = find.byWidgetPredicate(
      (w) =>
          w is ConstrainedBox &&
          w.constraints.maxWidth == AnimeXTokens.popoverWidth &&
          w.constraints.maxHeight == AnimeXTokens.popoverMaxHeight,
    );
    expect(popoverBox, findsOneWidget);

    final popoverSize = tester.getSize(popoverBox);

    // The popover must never balloon to fill the screen/overlay.
    expect(popoverSize.width, lessThanOrEqualTo(256.1));
    expect(popoverSize.height, lessThanOrEqualTo(320.1));

    final synopsisRect = tester.getRect(synopsisFinder);
    expect(
      synopsisRect.width,
      lessThan(256),
      reason: 'Popover text should stay inside the compact panel.',
    );

    // It should sit beside the card, not overlap it.
    final cardRect = tester.getRect(find.byType(AnimeXPosterCard));
    expect(synopsisRect.left, greaterThan(cardRect.right - 1));

    // The popover now carries the title so it shows real details.
    expect(
      find.text('I Want to Love You Till Your Dying Day'),
      findsNWidgets(2),
    );

    // Moving the pointer onto the popover must not dismiss it.
    await gesture.moveTo(tester.getCenter(popoverBox));
    await tester.pump(const Duration(milliseconds: 400));
    expect(popoverBox, findsOneWidget);

    // Leaving the popover dismisses it.
    await gesture.moveTo(const Offset(640, 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(popoverBox, findsNothing);
  });

  testWidgets('hover popover renders enriched details when resolved in cache', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimItem = MediaItem(
      id: 'bleach-1',
      tmdbId: 269,
      title: 'Bleach',
      mediaType: 'tv',
      posterPath: '',
      year: '2004',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
    );
    addTearDown(AnimeXPosterCard.clearResolvedCacheForTesting);

    // Pre-populate resolved cache for Bleach (malId: 269 -> 'm269')
    AnimeXPosterCard.cacheResolvedForTesting(
      'm269',
      slimItem.copyWith(
        synopsis: 'Ichigo Kurosaki is a high schooler who can see ghosts.',
        genres: const ['Action', 'Adventure', 'Supernatural'],
        score: 7.9,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXPosterCard(
            item: slimItem,
            width: 175,
            onTap: () {},
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(AnimeXPosterCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Popover is displayed with Bleach enriched details
    expect(find.text('Bleach'), findsNWidgets(2));
    expect(find.textContaining('Ichigo Kurosaki'), findsOneWidget);
    expect(find.text('ACTION'), findsOneWidget);
    // Score is rendered on both the card rating badge and the popover
    expect(find.text('7.9'), findsNWidgets(2));
    expect(find.text('Details →'), findsOneWidget);
  });
}
