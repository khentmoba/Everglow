import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';

/// Tests for [EverglowMarquee] carousel behavior across shelves.
///
/// Shelves with fewer than 3 items (1 or 2 items) render each child exactly once
/// without tiling or auto-scrolling to prevent duplicate covers on short shelves.
/// Shelves with 3 or more items tile seamlessly to fill the viewport and auto-scroll
/// so media rails (Cinema, Anime, Books, Reading, Gallery) smoothly carousel.
void main() {
  Widget harness({
    required double width,
    required List<Widget> children,
    bool edgeFade = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: EverglowMarquee(
              height: 194,
              edgeFade: edgeFade,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Finder edgeFadeOverlay() => find.byWidgetPredicate(
    (w) => w is ShaderMask && w.blendMode == BlendMode.dstIn,
  );

  List<Widget> cards(List<String> titles) => [
    for (final t in titles) SizedBox(width: 128, height: 186, child: Text(t)),
  ];

  testWidgets('single-item row renders exactly once without duplicates or auto-scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['A Shop for Killers'])),
    );
    await tester.pump();

    // Renders exactly once — no duplicates
    expect(find.text('A Shop for Killers'), findsOneWidget);
    // Does not run a ticker callback
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('two-item row renders each child exactly once (no tiling or auto-scroll)', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    // Renders each child exactly once
    expect(find.text('Movie A'), findsOneWidget);
    expect(find.text('Movie B'), findsOneWidget);

    final before = tester.getTopLeft(find.text('Movie A'));

    // Advance ~2 seconds of frames
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Position unchanged — static
    expect(tester.getTopLeft(find.text('Movie A')), before);
    expect(find.text('Movie A'), findsOneWidget);
    expect(find.text('Movie B'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('row with 3 or more items tiles and auto-scrolls seamlessly', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B', 'Movie C'])),
    );
    await tester.pump();

    // Tiles enough sets to fill the viewport + seamless wrap
    expect(find.text('Movie A'), findsWidgets);
    expect(find.text('Movie B'), findsWidgets);
    expect(find.text('Movie C'), findsWidgets);

    final before = tester.getTopLeft(find.text('Movie A').first);

    // Advance ~2 seconds of ticker frames.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final after = tester.getTopLeft(find.text('Movie A').first);
    expect(after.dx, lessThan(before.dx));
  });

  testWidgets('overflowing row still auto-scrolls without going blank', (
    tester,
  ) async {
    final titles = [for (var i = 0; i < 12; i++) 'Item $i'];
    await tester.pumpWidget(harness(width: 800, children: cards(titles)));
    await tester.pump();
    final before = tester.getTopLeft(find.text('Item 0').first);

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final after = tester.getTopLeft(find.text('Item 0').first);
    // Marquee drifts left over time.
    expect(after.dx, lessThan(before.dx));
    // Every title remains in the tree (seamless loop keeps a full set
    // on screen instead of scrolling into a blank gap).
    for (final t in titles) {
      expect(find.text(t), findsWidgets);
    }
  });

  testWidgets('empty children render nothing', (tester) async {
    await tester.pumpWidget(harness(width: 800, children: const []));
    await tester.pump();
    expect(find.byType(EverglowMarquee), findsOneWidget);
  });

  testWidgets('overflowing row fades its clip edges', (tester) async {
    final titles = [for (var i = 0; i < 12; i++) 'Item $i'];
    await tester.pumpWidget(harness(width: 800, children: cards(titles)));
    await tester.pump();

    expect(edgeFadeOverlay(), findsOneWidget);
  });

  testWidgets('short row (<3 items) renders no edge fade', (tester) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    expect(edgeFadeOverlay(), findsNothing);
  });

  testWidgets('drifting row ticks, and stops while hovered', (tester) async {
    final titles = [for (var i = 0; i < 12; i++) 'Item $i'];
    await tester.pumpWidget(harness(width: 800, children: cards(titles)));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(5, 5));
    addTearDown(gesture.removePointer);

    // Hover holds the drift still — so stop paying for frames too.
    await gesture.moveTo(tester.getCenter(find.byType(EverglowMarquee)));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);

    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('edgeFade false disables the overlay on overflowing rows', (
    tester,
  ) async {
    final titles = [for (var i = 0; i < 12; i++) 'Item $i'];
    await tester.pumpWidget(
      harness(width: 800, children: cards(titles), edgeFade: false),
    );
    await tester.pump();

    expect(edgeFadeOverlay(), findsNothing);
  });
}
