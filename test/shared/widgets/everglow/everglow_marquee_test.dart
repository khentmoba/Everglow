import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';

/// Tests for [EverglowMarquee] carousel behavior across shelves.
///
/// Shelves with fewer items (such as 1 or 2 items) space the second set off-screen
/// so the row carousels normally without showing duplicate covers side-by-side.
/// Shelves with overflowing items tile seamlessly to fill the viewport and auto-scroll
/// so all media rails (Cinema, Anime, Books, Reading, Gallery) smoothly carousel.
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

  testWidgets('single-item row carousels normally with off-screen loop set (no side-by-side duplicates)', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['A Shop for Killers'])),
    );
    await tester.pump();

    // Exactly 1 set visible on screen (second set placed off-screen at x >= 800)
    final firstCard = tester.getTopLeft(find.text('A Shop for Killers').first);
    final secondCard = tester.getTopLeft(find.text('A Shop for Killers').last);
    expect(firstCard.dx, closeTo(0.0, 1.0));
    expect(secondCard.dx, greaterThanOrEqualTo(780.0));

    // Auto-scrolls smoothly over time
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final after = tester.getTopLeft(find.text('A Shop for Killers').first);
    expect(after.dx, lessThan(firstCard.dx));
  });

  testWidgets('two-item row carousels normally without side-by-side duplicates', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    // First set is on screen, second set is off-screen
    final firstA = tester.getTopLeft(find.text('Movie A').first);
    final secondA = tester.getTopLeft(find.text('Movie A').last);
    expect(firstA.dx, closeTo(0.0, 1.0));
    expect(secondA.dx, greaterThanOrEqualTo(780.0));

    // Auto-scrolls smoothly over time
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final after = tester.getTopLeft(find.text('Movie A').first);
    expect(after.dx, lessThan(firstA.dx));
  });

  testWidgets('row with 3 or more items tiles and auto-scrolls seamlessly', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B', 'Movie C'])),
    );
    await tester.pump();

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

  testWidgets('short row fades its clip edges when edgeFade is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    expect(edgeFadeOverlay(), findsOneWidget);
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
