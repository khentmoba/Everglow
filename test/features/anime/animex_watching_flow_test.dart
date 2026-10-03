import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/data/services/aniskip_service.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_home_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_watch_page.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

MediaItem anime({
  int id = 20,
  int episode = 7,
  int timestamp = 360,
  int duration = 1440,
  String status = 'watching-self',
  bool movie = false,
  DateTime? updated,
}) => MediaItem(
  id: 'demo-$id',
  tmdbId: id,
  anilistId: id + 100,
  title: 'Demo Anime $id',
  mediaType: movie ? 'movie' : 'tv',
  posterPath: '',
  status: status,
  isAnime: true,
  addedAt: DateTime(2026),
  source: 'jikan',
  currentEpisode: movie ? null : episode,
  currentTimestamp: timestamp,
  durationSeconds: duration,
  episodeCount: movie ? 1 : 12,
  progressUpdatedAt: updated ?? DateTime(2026, 10, 1),
);

class DemoController extends AnimeXController {
  List<MediaItem> items;
  DemoController(this.items);
  @override
  List<MediaItem> get library => items;
  @override
  List<AnimexHistoryEntry> get watchHistory =>
      AnimeXController.historyFromLibrary(items);
  @override
  List<AnimexHistoryEntry> get continueWatching =>
      watchHistory.where((e) => e.savedItem!.isCurrentlyWatching).toList();
  void replace(List<MediaItem> next) {
    items = next;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'account history keeps progress, films and most recently watched first',
    () {
      final recent = anime(id: 30, movie: true, updated: DateTime(2026, 10, 2));
      final old = anime();
      final planned = MediaItem(
        id: 'plan',
        tmdbId: 31,
        title: 'Planned',
        mediaType: 'tv',
        posterPath: '',
        status: 'to-watch',
        isAnime: true,
        addedAt: DateTime(2026, 10, 3),
      );
      final entries = AnimeXController.historyFromLibrary([
        old,
        planned,
        recent,
      ]);
      expect(entries.map((e) => e.title), [recent.title, old.title]);
      expect(entries.first.isMovie, true);
      expect(entries.first.resumeLabel, 'Resume movie');
      expect(entries.last.resumeLabel, 'Resume Episode 7');
      expect(entries.last.resumeSeconds, 360);
      expect(mediaItemFromHistory(entries.first), same(recent));
    },
  );

  test(
    'fresh device resumes account episode/time, not older local history',
    () {
      final oldLocal = AnimexHistoryEntry(
        key: 'animex-120',
        anilistId: 120,
        malId: 20,
        title: 'Demo',
        coverUrl: '',
        episode: 2,
        updatedAt: DateTime(2026),
      );
      final resume = AnimeXWatchPage.resolveResume(
        item: anime(episode: 1, timestamp: 0),
        saved: anime(),
        local: oldLocal,
      );
      expect(resume.episode, 7);
      expect(resume.seconds, 360);
    },
  );

  test('explicit episode never seeks to another episode resume point', () {
    final resume = AnimeXWatchPage.resolveResume(
      item: anime(),
      saved: anime(),
      requestedEpisode: 3,
    );
    expect(resume.episode, 3);
    expect(resume.seconds, isNull);
  });

  test('finished titles and credits do not resume stale timestamps', () {
    final done = AnimeXWatchPage.resolveResume(
      item: anime(),
      saved: anime(status: 'watched-self'),
    );
    expect(done.episode, 1);
    expect(done.seconds, isNull);
    final credits = AnimeXWatchPage.resolveResume(item: anime(timestamp: 1400));
    expect(credits.seconds, isNull);
  });

  test('account reset never restores another device’s stale local episode', () {
    final cleared = MediaItem(
      id: 'cleared',
      tmdbId: 20,
      anilistId: 120,
      title: 'Demo',
      mediaType: 'tv',
      posterPath: '',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime(2026),
      progressUpdatedAt: DateTime(2026, 10, 3),
    );
    final stale = AnimexHistoryEntry(
      key: 'animex-120',
      malId: 20,
      title: 'Demo',
      coverUrl: '',
      episode: 7,
      updatedAt: DateTime(2026),
    );
    final resume = AnimeXWatchPage.resolveResume(
      item: cleared,
      saved: cleared,
      local: stale,
    );
    expect(resume.episode, 1);
    expect(resume.seconds, isNull);
  });

  test('manual guidance ignores stale telemetry on unsupported players', () {
    const opening = AniSkipTime(start: 0, end: 90);
    expect(
      AnimeXWatchPage.skipGuidanceVisible(opening, 360, supportsSeek: false),
      true,
    );
    expect(
      AnimeXWatchPage.skipGuidanceVisible(opening, 360, supportsSeek: true),
      false,
    );
    expect(
      AnimeXWatchPage.skipGuidanceVisible(opening, null, supportsSeek: true),
      true,
    );
  });

  testWidgets(
    'episode metadata stays withheld until account resume completes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AnimexStores.instance.resetForTest();
      await AnimexStores.instance.load(username: 'demo');
      await AnimexStores.instance.recordWatch(
        key: 'animex-0',
        malId: 0,
        title: 'Demo',
        coverUrl: '',
        episode: 7,
      );
      final controller = AnimeXController();
      addTearDown(controller.dispose);
      controller.openWatch(
        MediaItem(
          id: 'demo',
          tmdbId: 0,
          title: 'Demo',
          mediaType: 'tv',
          posterPath: '',
          status: 'to-watch',
          isAnime: true,
          addedAt: DateTime(2026),
        ),
      );
      final pending = Completer<MediaItem?>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AnimexStores.instance,
          child: MaterialApp(
            home: Scaffold(
              body: AnimeXWatchPage(
                controller: controller,
                loadSavedProgress: (_) => pending.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Hide spoilers'), findsNothing);
      pending.complete(anime(episode: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hide spoilers'), findsOneWidget);
      expect(find.text('Episode 2'), findsWidgets);
      controller.closeDetail();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  test('only servers with implemented capabilities offer controls', () {
    final servers = AnimeXWatchPage.buildServers(
      anilistId: 120,
      malId: 20,
      tmdbId: 44,
    );
    final ownEmbed = servers.firstWhere((s) => s.name == 'Everglow');
    final direct = servers.firstWhere((s) => s.name == 'Megavid');
    final external = servers.firstWhere((s) => s.name == 'MegaPlay');
    expect(ownEmbed.supportsAudioSelection, false);
    expect(ownEmbed.supportsSeek, false);
    expect(direct.supportsAudioSelection, true);
    expect(direct.supportsSeek, true);
    expect(
      Uri.parse(direct.urlFor(7, 'dub', startSeconds: 360)).queryParameters,
      containsPair('start', '360'),
    );
    expect(
      Uri.parse(direct.urlFor(7, 'dub', startSeconds: 360)).queryParameters,
      containsPair('audio', 'dub'),
    );
    expect(
      Uri.parse(ownEmbed.urlFor(7, 'sub', startSeconds: 360)).queryParameters,
      containsPair('start', '360'),
    );
    expect(
      external.urlFor(7, 'sub', startSeconds: 360),
      external.urlBuilder(7, 'sub'),
    );
    expect(
      direct.urlFor(7, 'sub', startSeconds: -1),
      direct.urlBuilder(7, 'sub'),
    );
  });

  testWidgets(
    'Continue Watching is immediately below spotlight and follows account updates',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = DemoController([anime()]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXHomePage(
              controller: controller,
              loadSchedule: (_) async => [],
              loadRow: (_) async => const AnimexMediaPage(
                items: [],
                scores: [],
                currentPage: 1,
                hasNextPage: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Continue Watching'), findsOneWidget);
      expect(find.text('Resume Episode 7 · 6:00'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Continue Watching')).dy,
        lessThan(932),
      );
      expect(find.text('Trending This Week'), findsNothing);
      controller.replace([anime(episode: 8, timestamp: 600)]);
      await tester.pump();
      expect(find.text('Resume Episode 8 · 10:00'), findsOneWidget);
      controller.replace([anime(status: 'watched-self')]);
      await tester.pump();
      expect(find.text('Continue Watching'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
