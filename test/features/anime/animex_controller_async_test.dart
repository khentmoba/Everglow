import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

MediaItem _anime({int episode = 2, String user = 'demo-a'}) => MediaItem(
  id: 'demo-$user',
  tmdbId: 20,
  anilistId: 120,
  title: 'Demo Anime',
  mediaType: 'tv',
  posterPath: 'old-poster',
  status: 'watching-self',
  isAnime: true,
  userName: user,
  addedAt: DateTime(2026),
  currentEpisode: episode,
  currentTimestamp: episode * 60,
  durationSeconds: 1440,
);

// Real stream listener and controllable poster futures; no Firebase or network.
class _LibrarySource {
  final streams = <StreamController<List<MediaItem>>>[];
  final posterRequests = <List<MediaItem>>[];
  final posters = <Completer<List<MediaItem>>>[];

  Stream<List<MediaItem>> stream(String user) {
    final controller = StreamController<List<MediaItem>>(sync: true);
    streams.add(controller);
    return controller.stream;
  }

  Future<List<MediaItem>> refresh(List<MediaItem> items) {
    posterRequests.add(items);
    final pending = Completer<List<MediaItem>>();
    posters.add(pending);
    return pending.future;
  }

  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}

Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  late _LibrarySource source;
  late AnimeXController controller;

  setUp(() {
    source = _LibrarySource();
    controller = AnimeXController(
      watchlistStream: source.stream,
      refreshPosters: source.refresh,
    );
    addTearDown(source.close);
  });

  test('raw account progress publishes before poster enrichment', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    expect(controller.libraryLoading, true);
    source.streams.single.add([_anime(episode: 7)]);

    expect(controller.libraryLoading, false);
    expect(controller.library.single.currentEpisode, 7);
    expect(controller.watchHistory.single.episode, 7);
    expect(controller.continueWatching.single.resumeSeconds, 420);
    expect(controller.savedAnime(_anime())!.currentEpisode, 7);

    source.posters.single.complete([
      source.posterRequests.single.single.copyWith(posterPath: 'fresh-poster'),
    ]);
    await _drain();
    expect(controller.library.single.posterPath, 'fresh-poster');
    expect(controller.continueWatching.single.episode, 7);
  });

  test('older poster result cannot revert a newer episode snapshot', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime()]);
    source.streams.single.add([_anime(episode: 8)]);
    source.posters[1].complete([
      source.posterRequests[1].single.copyWith(posterPath: 'new-poster'),
    ]);
    await _drain();
    expect(controller.continueWatching.single.episode, 8);
    var notifications = 0;
    controller.addListener(() => notifications++);

    source.posters[0].complete([
      source.posterRequests[0].single.copyWith(posterPath: 'stale-poster'),
    ]);
    await _drain();
    expect(controller.library.single.currentEpisode, 8);
    expect(controller.library.single.posterPath, 'new-poster');
    expect(controller.watchHistory.single.episode, 8);
    expect(controller.savedAnime(_anime())!.currentTimestamp, 480);
    expect(notifications, 0);
  });

  test('older poster result cannot restore a removed anime', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime()]);
    source.streams.single.add([]);
    source.posters[1].complete([]);
    await _drain();
    expect(controller.library, isEmpty);

    source.posters[0].complete(source.posterRequests[0]);
    await _drain();
    expect(controller.library, isEmpty);
    expect(controller.watchHistory, isEmpty);
    expect(controller.continueWatching, isEmpty);
    expect(controller.savedAnime(_anime()), isNull);
  });

  test('old completion cannot gate newer raw progress or removal', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime()]);
    source.streams.single.add([_anime(episode: 9)]);
    expect(controller.continueWatching.single.episode, 9);
    source.posters[0].complete(source.posterRequests[0]);
    await _drain();
    expect(controller.continueWatching.single.episode, 9);

    source.streams.single.add([]);
    expect(controller.library, isEmpty);
    expect(controller.libraryLoading, false);
    source.posters[1].complete(source.posterRequests[1]);
    await _drain();
    expect(controller.library, isEmpty);
    source.posters[2].complete([]);
    await _drain();
    expect(controller.continueWatching, isEmpty);
  });

  test('A to B to A rejects results from both old subscriptions', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams[0].add([_anime()]);
    controller.openWatch(_anime(), episode: 2);
    controller.loadLibrary('demo-b');
    expect(controller.library, isEmpty);
    expect(controller.watchItem, isNull);
    expect(controller.watchEpisode, isNull);
    source.streams[1].add([_anime(episode: 3, user: 'demo-b')]);
    controller.loadLibrary('demo-a');
    source.streams[2].add([_anime(episode: 10)]);
    source.posters[2].complete(source.posterRequests[2]);
    await _drain();
    expect(controller.continueWatching.single.episode, 10);

    source.posters[1].complete(source.posterRequests[1]);
    source.posters[0].complete(source.posterRequests[0]);
    await _drain();
    expect(controller.library.single.userName, 'demo-a');
    expect(controller.continueWatching.single.episode, 10);
  });

  test('A to B to A rejects old A before the new stream emits', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams[0].add([_anime()]);
    controller.loadLibrary('demo-b');
    controller.loadLibrary('demo-a');

    // No newer snapshot has incremented the snapshot generation yet; the
    // subscription generation must reject the old result even for owner A.
    source.posters[0].complete(source.posterRequests[0]);
    await _drain();
    expect(controller.library, isEmpty);
    expect(controller.libraryLoading, true);

    source.streams[2].add([_anime(episode: 11)]);
    expect(controller.continueWatching.single.episode, 11);
    expect(source.posters, hasLength(2));
    source.posters[1].complete(source.posterRequests[1]);
    await _drain();
    expect(controller.continueWatching.single.episode, 11);
  });

  test('poster failure leaves the latest raw progress available', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime(episode: 7)]);
    source.posters.single.completeError(StateError('demo poster failure'));
    await _drain();
    expect(controller.libraryLoading, false);
    expect(controller.continueWatching.single.episode, 7);

    source.streams.single.add([_anime(episode: 8)]);
    expect(controller.continueWatching.single.episode, 8);
    source.posters[1].complete(source.posterRequests[1]);
    await _drain();
    expect(controller.continueWatching.single.episode, 8);
  });

  test('logout rejects pending poster results', () async {
    addTearDown(controller.dispose);
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime()]);
    controller.loadLibrary('');
    source.posters.single.complete(source.posterRequests.single);
    await _drain();
    expect(controller.library, isEmpty);
    expect(controller.libraryLoading, false);
    expect(source.streams, hasLength(1));
  });

  test('dispose rejects pending results and further loads', () async {
    controller.loadLibrary('demo-a');
    source.streams.single.add([_anime()]);
    final beforeDispose = controller.library;
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();

    source.posters.single.complete([
      _anime(episode: 12).copyWith(posterPath: 'stale-poster'),
    ]);
    await _drain();
    controller.loadLibrary('demo-b');
    expect(controller.library, beforeDispose);
    expect(notifications, 0);
    expect(source.streams, hasLength(1));
  });
}
