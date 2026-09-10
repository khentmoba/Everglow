import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_grid.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_row.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_skeleton.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';

MediaItem _itemWithTitle(
  String title, {
  String year = '2026',
  String format = 'TV',
}) {
  return MediaItem(
    id: 'test-1',
    tmdbId: 1,
    title: title,
    mediaType: 'tv',
    posterPath: '',
    year: year,
    status: 'to-watch',
    isAnime: true,
    addedAt: DateTime(2026, 1, 1),
    source: 'jikan',
    format: format,
  );
}

void main() {
  testWidgets('poster row fits 2-line title and metadata without clipping', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _itemWithTitle(
        'From Overshadowed to Overpowered: Second Round In Another World',
      ),
      _itemWithTitle('ONE PIECE', year: '1999'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXPosterRow(
            items: items,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byType(AnimeXPosterRow);
    expect(rowFinder, findsOneWidget);

    final metaFinder = find.text('2026 · TV');
    expect(metaFinder, findsOneWidget);

    final rowRect = tester.getRect(rowFinder);
    final metaRect = tester.getRect(metaFinder);

    expect(
      metaRect.bottom,
      lessThanOrEqualTo(rowRect.bottom),
      reason:
          'Metadata line must be fully contained inside the row bounds to avoid clipping/halving',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('poster row has no overflow on a 360px phone', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _itemWithTitle(
        'From Overshadowed to Overpowered: Second Round In Another World',
      ),
      _itemWithTitle('ONE PIECE', year: '1999'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXPosterRow(
            items: items,
            cardWidth: AnimeXTokens.rowPosterWidthMobile,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('poster row has no overflow on an 810px tablet', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(810, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _itemWithTitle(
        'From Overshadowed to Overpowered: Second Round In Another World',
      ),
      _itemWithTitle('Re:ZERO - Starting Life in Another World - Season 4'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXPosterRow(
            items: items,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton row height matches poster row height', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeXSkeletonRow(cardWidth: AnimeXTokens.rowPosterWidthDesktop),
        ),
      ),
    );
    await tester.pump();

    final skeletonSize = tester.getSize(find.byType(AnimeXSkeletonRow));
    const expectedHeight =
        AnimeXTokens.rowPosterWidthDesktop * 1.5 +
        AnimeXTokens.posterDetailsHeight;
    expect(skeletonSize.height, equals(expectedHeight));
  });

  testWidgets('anime grid fits 2-line title and metadata without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = [
      _itemWithTitle(
        'From Overshadowed to Overpowered: Second Round In Another World',
      ),
      _itemWithTitle('Re:ZERO - Starting Life in Another World - Season 4'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnimeXGrid(
              items: items,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final metaFinder = find.text('2026 · TV');
    expect(metaFinder, findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
