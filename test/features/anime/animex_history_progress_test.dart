import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';

AnimexHistoryEntry _entry({required int episode, required int total}) {
  return AnimexHistoryEntry(
    key: 'animex-1',
    malId: 1,
    title: 'Fake Show',
    coverUrl: '',
    episode: episode,
    totalEpisodes: total,
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('AnimexHistoryEntry.seriesProgress', () {
    test('is completed episodes over total', () {
      expect(_entry(episode: 6, total: 12).seriesProgress, closeTo(5 / 12, 1e-9));
      expect(_entry(episode: 1, total: 12).seriesProgress, 0.0);
      expect(_entry(episode: 12, total: 12).seriesProgress, closeTo(11 / 12, 1e-9));
    });

    test('is null when there is nothing truthful to draw', () {
      expect(_entry(episode: 3, total: 0).seriesProgress, isNull);
      expect(_entry(episode: 1, total: 1).seriesProgress, isNull);
    });

    test('clamps stale episode numbers', () {
      expect(_entry(episode: 99, total: 12).seriesProgress, 1.0);
    });

    test('survives a JSON round-trip', () {
      final entry = _entry(episode: 6, total: 24);
      final revived = AnimexHistoryEntry.fromJson(entry.toJson());
      expect(revived.episode, 6);
      expect(revived.totalEpisodes, 24);
      expect(revived.seriesProgress, entry.seriesProgress);
    });

    test('old entries without a total read as unknown', () {
      final revived = AnimexHistoryEntry.fromJson({
        'key': 'animex-1',
        'malId': 1,
        'title': 'Legacy Show',
        'coverUrl': '',
        'episode': 3,
        'durationSeconds': 0,
        'episodeMinutes': 24,
        'updatedAt': 0,
      });
      expect(revived.totalEpisodes, 0);
      expect(revived.seriesProgress, isNull);
    });
  });

  group('AnimexStores history totals', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AnimexStores.instance.resetForTest();
    });

    test('recordWatch persists the series total', () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'khentsgdz');
      await stores.recordWatch(
        key: 'animex-1',
        malId: 1,
        title: 'Fake Show',
        coverUrl: '',
        episode: 6,
        totalEpisodes: 12,
      );
      expect(stores.history.single.seriesProgress, closeTo(5 / 12, 1e-9));

      await stores.switchUser('clairjassen');
      await stores.switchUser('khentsgdz');
      expect(stores.history.single.totalEpisodes, 12);
    });
  });
}
