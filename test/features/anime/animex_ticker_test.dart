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

    await tester.pump();

    Finder findTrackTransform() {
      return find.descendant(
        of: find.byType(AnimeXTicker),
        matching: find.byWidgetPredicate((w) => w is Transform),
      );
    }

    Transform getTransform() => tester.widget<Transform>(findTrackTransform());

    expect(getTransform().transform.getTranslation().x, equals(0.0));

    await tester.pump(const Duration(seconds: 2));

    final offsetBeforeHover = getTransform().transform.getTranslation().x;
    expect(offsetBeforeHover, lessThan(0.0));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(AnimeXTicker)));
    await tester.pump();

    expect(getTransform().transform.getTranslation().x, equals(offsetBeforeHover));

    await tester.pump(const Duration(seconds: 2));
    expect(getTransform().transform.getTranslation().x, equals(offsetBeforeHover));

    await gesture.moveTo(const Offset(900, 900));
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    final offsetAfterResume = getTransform().transform.getTranslation().x;
    expect(offsetAfterResume, lessThan(offsetBeforeHover));
  });

  testWidgets('AnimeXTicker adapts label based on viewport width', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    final items = _sampleItems();

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            child: AnimeXTicker(items: items),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('AIRING TODAY'), findsOneWidget);
    expect(find.text('AIRING'), findsNothing);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            child: AnimeXTicker(items: items),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('AIRING'), findsOneWidget);
    expect(find.text('AIRING TODAY'), findsNothing);
  });

  testWidgets('AnimeXTicker confines scrolling track inside Expanded and ClipRect', (
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
    await tester.pump();

    final rowFinder = find.descendant(
      of: find.byType(AnimeXTicker),
      matching: find.byType(Row),
    );
    expect(rowFinder, findsWidgets);

    final clipRectFinder = find.descendant(
      of: find.byType(AnimeXTicker),
      matching: find.byType(ClipRect),
    );
    expect(clipRectFinder, findsOneWidget);

    final shaderMaskFinder = find.descendant(
      of: find.byType(AnimeXTicker),
      matching: find.byType(ShaderMask),
    );
    expect(shaderMaskFinder, findsOneWidget);

    final labelTopLeft = tester.getTopLeft(find.text('AIRING TODAY'));
    final clipRectTopLeft = tester.getTopLeft(clipRectFinder);
    expect(clipRectTopLeft.dx, greaterThan(labelTopLeft.dx));
  });

  testWidgets('AnimeXTicker invokes onTap callback when an item is tapped', (
    WidgetTester tester,
  ) async {
    final items = _sampleItems();
    MediaItem? tappedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 40,
            child: AnimeXTicker(
              items: items,
              onTap: (item) => tappedItem = item,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Frieren: Beyond Journey\'s End').first);
    await tester.pump();

    expect(tappedItem, isNotNull);
    expect(tappedItem!.id, equals('anime-1'));
  });
}
