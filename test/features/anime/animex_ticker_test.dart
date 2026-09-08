import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_ticker.dart';

List<MediaItem> _sampleItems() {
  return [
    MediaItem(
      id: 'anime-1',
      tmdbId: 0,
      title: 'Frieren: Beyond Journey\'s End',
      mediaType: 'tv',
      posterPath: '',
      year: '2026',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      currentEpisode: 28,
    ),
    MediaItem(
      id: 'anime-2',
      tmdbId: 0,
      title: 'Solo Leveling',
      mediaType: 'tv',
      posterPath: '',
      year: '2026',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026, 1, 1),
      source: 'jikan',
      currentEpisode: 12,
    ),
  ];
}

void main() {
  testWidgets('AnimeXTicker pauses in place on hover without resetting to start', (
    WidgetTester tester,
  ) async {
    final items = _sampleItems();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 40,
            child: AnimeXTicker(items: items),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Find the Transform widget responsible for translating the track.
    // It's the Transform.translate inside AnimeXTicker.
    Finder findTrackTransform() {
      return find.descendant(
        of: find.byType(AnimeXTicker),
        matching: find.byWidgetPredicate((w) => w is Transform),
      );
    }

    Transform getTransform() => tester.widget<Transform>(findTrackTransform());

    // Initially at offset 0
    expect(getTransform().transform.getTranslation().x, equals(0.0));

    // Advance animation by 2 seconds (out of 40s duration, 2/40 = 0.05 of track width)
    await tester.pump(const Duration(seconds: 2));

    final offsetBeforeHover = getTransform().transform.getTranslation().x;
    // Offset should be negative (translated left)
    expect(offsetBeforeHover, lessThan(0.0));

    // Hover over the ticker
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(AnimeXTicker)));
    await tester.pump();

    // Crucial check: on hover, it must NOT reset to 0.0 (the preset).
    // It must stay at exactly offsetBeforeHover.
    expect(getTransform().transform.getTranslation().x, equals(offsetBeforeHover));

    // Wait another 2 seconds while hovering: it should remain paused at the exact same offset
    await tester.pump(const Duration(seconds: 2));
    expect(getTransform().transform.getTranslation().x, equals(offsetBeforeHover));

    // Move mouse away (unhover)
    await gesture.moveTo(const Offset(900, 900));
    await tester.pump();

    // Advance another 2 seconds: it should resume and advance further
    await tester.pump(const Duration(seconds: 2));
    final offsetAfterResume = getTransform().transform.getTranslation().x;
    expect(offsetAfterResume, lessThan(offsetBeforeHover));
  });
}
