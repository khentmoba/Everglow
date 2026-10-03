import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_row.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_home_tab.dart';

MediaItem demo() => MediaItem(
  id: 'demo',
  tmdbId: 1,
  title: 'Demo series',
  mediaType: 'tv',
  posterPath: '',
  status: 'watching-self',
  currentSeason: 2,
  currentEpisode: 3,
  currentTimestamp: 600,
  durationSeconds: 1800,
  addedAt: DateTime(2026),
);

Widget home({
  bool loading = true,
  List<MediaItem> watching = const [],
  void Function(MediaItem)? restart,
  Future<void> Function()? refresh,
}) => CinemaHomeTab(
  isLoadingHome: loading,
  trendingCarousel: [],
  popularTVShows: [],
  newlyReleased: [],
  watchingList: watching,
  trendingGlobal: [],
  topTenToday: [],
  onRefresh: refresh ?? () async {},
  onMediaTap: (_) {},
  onPlay: (_) {},
  onRestart: restart,
  onSwitchTab: (_) {},
);

void main() {
  for (final width in [360.0, 390.0, 430.0, 810.0]) {
    testWidgets('actual home loading fits ${width}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: home())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Continue Watching is available before catalogue finishes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final item = demo();
    MediaItem? restarted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: home(watching: [item], restart: (item) => restarted = item),
        ),
      ),
    );
    expect(find.text('Continue Watching'), findsOneWidget);
    final row = tester.widget<NetflixContinueRow>(
      find.byType(NetflixContinueRow),
    );
    expect(row.subtitleOf(item), 'S2 · E3 · 20m left');
    row.onRestart!(item);
    expect(restarted, same(item));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty catalogue offers retry instead of a blank home', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: home(loading: false, refresh: () async => retried = true),
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'cleared progress preserves the saved title but not the resume offset',
    () {
      final cleared = demo().copyWith(status: 'to-watch', clearProgress: true);
      expect(cleared.title, 'Demo series');
      expect(cleared.isCurrentlyWatching, isFalse);
      expect(cleared.currentSeason, isNull);
      expect(cleared.currentTimestamp, isNull);
      expect(cleared.durationSeconds, isNull);
    },
  );
}
