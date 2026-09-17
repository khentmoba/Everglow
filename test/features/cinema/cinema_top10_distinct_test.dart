import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_row.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_home_tab.dart';

MediaItem _fake(String title, int tmdbId) {
  return MediaItem(
    id: 'm$tmdbId',
    tmdbId: tmdbId,
    title: title,
    mediaType: 'movie',
    posterPath: '',
    backdropPath: '',
    year: '2026',
    status: 'to-watch',
    addedAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<MediaItem> trending,
  required List<MediaItem> topTen,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: CinemaHomeTab(
          isLoadingHome: false,
          trendingCarousel: const [],
          topRatedMovies: const [],
          popularTVShows: const [],
          nowShowing: const [],
          newlyReleased: const [],
          popularMovies: const [],
          topRatedTV: const [],
          airingToday: const [],
          onTheAir: const [],
          discoveryRows: const {},
          genreLists: const {},
          watchingList: const [],
          watchedList: const [],
          trendingGlobal: trending,
          topTenToday: topTen,
          onRefresh: () {},
          onMediaTap: (_) {},
          onPlay: (_) {},
          onSwitchTab: (_) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Top 10 Today renders its own feed, not Trending Now again', (
    tester,
  ) async {
    final trending = List.generate(
      12,
      (i) => _fake('Global Hit ${i + 1}', 1000 + i),
    );
    final topTen = List.generate(
      10,
      (i) => _fake('PH Favorite ${i + 1}', 2000 + i),
    );

    await _pumpHome(tester, trending: trending, topTen: topTen);
    expect(tester.takeException(), isNull);

    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Top 10 Today'), findsOneWidget);

    // Each rail must be fed its own list — Top 10 mirroring Trending
    // renders two identical rails back to back.
    final rows = tester
        .widgetList<NetflixRow>(find.byType(NetflixRow))
        .toList();
    expect(rows, hasLength(2));
    expect(
      rows[0].items.map((m) => m.tmdbId),
      trending.map((m) => m.tmdbId),
    );
    expect(rows[0].ranked, isFalse);
    expect(rows[1].items.map((m) => m.tmdbId), topTen.map((m) => m.tmdbId));
    expect(rows[1].ranked, isTrue);
  });

  testWidgets('Top 10 Today hides when its feed is empty', (tester) async {
    final trending = List.generate(
      12,
      (i) => _fake('Global Hit ${i + 1}', 1000 + i),
    );

    await _pumpHome(tester, trending: trending, topTen: const []);
    expect(tester.takeException(), isNull);

    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Top 10 Today'), findsNothing);
  });
}
