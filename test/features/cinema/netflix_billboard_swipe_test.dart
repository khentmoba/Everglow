import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_billboard.dart';

MediaItem _item(String title, int tmdbId) => MediaItem(
  id: 'test-$tmdbId',
  tmdbId: tmdbId,
  title: title,
  mediaType: 'movie',
  posterPath: '',
  status: 'watching',
  addedAt: DateTime(2026, 1, 1),
);

Future<void> _pumpBillboard(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NetflixBillboard(
          items: [_item('First Title', 1), _item('Second Title', 2)],
          onPlay: (_) {},
          onInfo: (_) {},
        ),
      ),
    ),
  );
}

/// Lets the 700ms crossfade finish after a gesture.
Future<void> _settleCrossfade(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  testWidgets('swiping left advances to the next slide', (tester) async {
    await _pumpBillboard(tester);
    expect(find.text('First Title'), findsOneWidget);

    await tester.fling(
      find.byType(NetflixBillboard),
      const Offset(-300, 0),
      1000,
    );
    await _settleCrossfade(tester);

    expect(find.text('Second Title'), findsOneWidget);
    expect(find.text('First Title'), findsNothing);
  });

  testWidgets('swiping right goes back to the previous slide', (
    tester,
  ) async {
    await _pumpBillboard(tester);

    await tester.fling(
      find.byType(NetflixBillboard),
      const Offset(-300, 0),
      1000,
    );
    await _settleCrossfade(tester);
    expect(find.text('Second Title'), findsOneWidget);

    await tester.fling(
      find.byType(NetflixBillboard),
      const Offset(300, 0),
      1000,
    );
    await _settleCrossfade(tester);
    expect(find.text('First Title'), findsOneWidget);
  });

  testWidgets('tapping a dot jumps straight to that slide', (tester) async {
    await _pumpBillboard(tester);

    await tester.tap(find.byKey(const ValueKey('billboard-dot-1')));
    await _settleCrossfade(tester);

    expect(find.text('Second Title'), findsOneWidget);
    expect(find.text('First Title'), findsNothing);
  });
}
