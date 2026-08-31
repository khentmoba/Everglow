import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_card.dart';

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
          w.constraints.maxWidth == 190 &&
          w.constraints.maxHeight == 220,
    );
    expect(popoverBox, findsOneWidget);

    final popoverSize = tester.getSize(popoverBox);

    // The popover must never balloon to fill the screen/overlay.
    expect(popoverSize.width, lessThanOrEqualTo(190.1));
    expect(popoverSize.height, lessThanOrEqualTo(220.1));

    final synopsisRect = tester.getRect(synopsisFinder);
    expect(
      synopsisRect.width,
      lessThan(190),
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
}
