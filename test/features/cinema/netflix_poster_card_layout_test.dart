import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';

MediaItem _item(int i) {
  return MediaItem(
    id: 'm$i',
    tmdbId: 1000 + i,
    title: 'A Very Long Cinema Title Number $i That Must Ellipsize Instead Of Overflowing',
    mediaType: 'movie',
    posterPath: '',
    backdropPath: '',
    year: '2026',
    status: 'to-watch',
    addedAt: DateTime(2026, 1, 1),
    source: 'tmdb',
  );
}

Future<void> _pumpGrid(WidgetTester tester, Size size, int columns) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 0.66,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, i) => NetflixPosterCard(
            item: _item(i),
            compact: true,
            progress: i.isEven ? 0.4 : null,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('NetflixPosterCard grid has no overflow on a 360px phone', (tester) async {
    await _pumpGrid(tester, const Size(360, 800), 2);
    final first = tester.getRect(find.byType(NetflixPosterCard).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('NetflixPosterCard grid has no overflow on an 810px tablet', (tester) async {
    await _pumpGrid(tester, const Size(810, 1080), 4);
    final first = tester.getRect(find.byType(NetflixPosterCard).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });
  testWidgets('NetflixPosterCard rank rail has no overflow on a 360px phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: NetflixPosterCard(
                      item: _item(i),
                      compact: true,
                      rank: i + 1,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
