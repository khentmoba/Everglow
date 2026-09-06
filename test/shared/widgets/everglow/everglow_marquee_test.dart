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
  Widget harness({required double width, required List<Widget> children}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: EverglowMarquee(height: 194, children: children),
          ),
        ),
      ),
    );
  }

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
}
