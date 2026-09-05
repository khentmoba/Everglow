import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/services/music_persistence_service.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/jukebox_provider.dart';

/// Fails the test when [condition] is not met within [timeout].
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

MusicStatus _liveStatus(String username) => MusicStatus(
  username: username,
  trackName: 'American Teenager',
  artistName: 'Ethel Cain',
  albumName: "Preacher's Daughter",
  isPlaying: true,
  spotifyUrl: 'https://open.spotify.com/search/Ethel%20Cain',
  timestamp: DateTime.utc(2026, 9, 6, 5, 0),
);

/// Subclassing is safe: [MusicPersistenceService] resolves Firestore lazily,
/// and this fake overrides every method that would touch it.
class _FakeStore extends MusicPersistenceService {
  final List<StreamController<Map<String, MusicStatus>>> controllers = [];
  final List<MusicStatus> saved = [];

  @override
  Stream<Map<String, MusicStatus>> musicStatusStream(List<String> usernames) {
    final controller = StreamController<Map<String, MusicStatus>>();
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<void> saveMusicStatus(MusicStatus status) async {
    saved.add(status);
  }
}

class _StubSync extends MusicSyncService {
  _StubSync(this.result);

  final MusicStatus? Function(String username)? result;

  @override
  Future<MusicStatus?> fetchRecentTrack(String username) async =>
      result?.call(username);
}

JukeboxProvider _provider({
  required _FakeStore store,
  MusicStatus? Function(String username)? fetch,
}) {
  final provider = JukeboxProvider(
    apiService: _StubSync(fetch),
    persistenceService: store,
    pollInterval: const Duration(hours: 1),
    resubscribeDelay: const Duration(milliseconds: 10),
  );
  addTearDown(provider.dispose);
  return provider;
}

void main() {
  group('JukeboxProvider live recovery', () {
    test('replays current state to new subscribers immediately', () async {
      final store = _FakeStore();
      final provider = _provider(store: store);

      final events = <Map<String, MusicStatus>>[];
      final sub = provider.statusStream.listen(events.add);
      addTearDown(sub.cancel);

      await _waitFor(() => events.isNotEmpty);
      // No Firestore data was ever emitted; the replay carries the sentinels.
      expect(events.single['khentsgdz']!.trackName, 'Silent Night');
      expect(events.single['clairjassen']!.trackName, 'Silent Night');
      expect(store.controllers.length, 1);
    });

    test('recovers after a Firestore stream error', () async {
      final store = _FakeStore();
      final provider = _provider(store: store);

      final events = <Map<String, MusicStatus>>[];
      final sub = provider.statusStream.listen(events.add);
      addTearDown(sub.cancel);
      await _waitFor(() => events.isNotEmpty);

      // First listen dies like an unauthenticated permission-denied.
      store.controllers.single.addError(Exception('permission-denied'));
      await _waitFor(() => store.controllers.length == 2);

      // Live data arriving on the replacement subscription reaches the UI.
      final live = _liveStatus('khentsgdz');
      store.controllers.last.add({'khentsgdz': live});
      await _waitFor(
        () =>
            events.isNotEmpty &&
            events.last['khentsgdz']?.trackName == 'American Teenager',
      );
      expect(events.last['khentsgdz']!.isPlaying, isTrue);
    });

    test('recovers after the stream closes without data', () async {
      final store = _FakeStore();
      final provider = _provider(store: store);

      final events = <Map<String, MusicStatus>>[];
      final sub = provider.statusStream.listen(events.add);
      addTearDown(sub.cancel);
      await _waitFor(() => events.isNotEmpty);

      // Mirrors withFirestoreTimeout closing a slow first snapshot.
      await store.controllers.single.close();
      await _waitFor(() => store.controllers.length == 2);

      final live = _liveStatus('clairjassen');
      store.controllers.last.add({'clairjassen': live});
      await _waitFor(
        () =>
            events.isNotEmpty &&
            events.last['clairjassen']?.trackName == 'American Teenager',
      );
    });

    test('stops retrying after dispose', () async {
      final store = _FakeStore();
      // No addTearDown: this test disposes the provider itself.
      final provider = JukeboxProvider(
        apiService: _StubSync(null),
        persistenceService: store,
        pollInterval: const Duration(hours: 1),
        resubscribeDelay: const Duration(milliseconds: 10),
      );
      expect(store.controllers.length, 1);

      provider.dispose();
      store.controllers.single.addError(Exception('permission-denied'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(store.controllers.length, 1);
    });

    test('polls Last.fm and persists the live status', () async {
      final store = _FakeStore();
      _provider(store: store, fetch: _liveStatus);

      await _waitFor(() => store.saved.length == 2);
      expect(
        store.saved.map((s) => s.username),
        containsAll(['khentsgdz', 'clairjassen']),
      );
      expect(store.saved.every((s) => s.isPlaying), isTrue);
    });
  });
}
