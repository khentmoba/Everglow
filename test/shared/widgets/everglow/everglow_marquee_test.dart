import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_marquee.dart';

/// Regression tests for the dashboard "duplicate covers" bug.
///
/// With only 1–2 titles in Currently Watching / Reading, the shelf showed
/// each cover 3 times (A B A B A B) because [EverglowMarquee] tiled short
/// rows to fill the viewport. Short rows must render each child exactly
/// once and stay put; only overflowing rows should auto-scroll.
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
    (w) =>
        w is Container &&
        w.foregroundDecoration is BoxDecoration &&
        (w.foregroundDecoration as BoxDecoration).gradient is LinearGradient,
  );

  List<Widget> cards(List<String> titles) => [
    for (final t in titles)
      SizedBox(width: 128, height: 186, child: Text(t)),
  ];

  testWidgets('short row renders each child exactly once (no tiling)', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    expect(find.text('Movie A'), findsOneWidget);
    expect(find.text('Movie B'), findsOneWidget);
  });

  testWidgets('short row does not auto-scroll', (tester) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();
    final before = tester.getTopLeft(find.text('Movie A'));

    // Advance ~2 seconds of ticker frames.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.getTopLeft(find.text('Movie A')), before);
    expect(find.text('Movie A'), findsOneWidget);
    expect(find.text('Movie B'), findsOneWidget);
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

  testWidgets('fitting row renders no edge fade', (tester) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    expect(edgeFadeOverlay(), findsNothing);
  });

  testWidgets('fitting row does not keep the frame loop alive', (tester) async {
    await tester.pumpWidget(
      harness(width: 800, children: cards(['Movie A', 'Movie B'])),
    );
    await tester.pump();

    // Nothing on screen can move, so no ticker should be scheduled: a fitting
    // row used to repeat the controller forever, waking the whole app 60x/sec.
    expect(tester.binding.transientCallbackCount, 0);
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
