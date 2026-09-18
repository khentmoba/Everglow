import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/anime/data/services/animex_stores.dart';

Future<void> _recordSample(AnimexStores stores, String title) {
  return stores.recordWatch(
    key: 'animex-1-$title',
    malId: 1,
    title: title,
    coverUrl: '',
    episode: 9,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AnimexStores.instance.resetForTest();
  });

  group('AnimexStores per-user scoping', () {
    test('history does not leak across profiles', () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'khentsgdz');
      await _recordSample(stores, 'Khent Show');
      expect(stores.history.map((e) => e.title), ['Khent Show']);

      // Same device, different profile: must start empty.
      await stores.switchUser('octagram');
      expect(stores.history, isEmpty);

      await _recordSample(stores, 'Octagram Show');
      expect(stores.history.map((e) => e.title), ['Octagram Show']);

      // Switching back restores the first profile untouched.
      await stores.switchUser('khentsgdz');
      expect(stores.history.map((e) => e.title), ['Khent Show']);
    });

    test('logout clears memory and never persists', () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'khentsgdz');
      await _recordSample(stores, 'Khent Show');

      await stores.switchUser(null);
      expect(stores.history, isEmpty);
      expect(stores.currentUser, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      // No global (unscoped) keys may be written.
      expect(prefs.getString('animex_watch_history_v1'), isNull);
    });

    test('legacy global history migrates only to couple profiles', () async {
      SharedPreferences.setMockInitialValues({
        'animex_watch_history_v1': json.encode([
          {
            'key': 'animex-1',
            'malId': 1,
            'title': 'Legacy Show',
            'coverUrl': '',
            'episode': 3,
            'durationSeconds': 0,
            'episodeMinutes': 24,
            'updatedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          },
        ]),
      });

      final stores = AnimexStores.instance;
      // Cinema-only profile must NOT inherit legacy watches.
      await stores.load(username: 'octagram');
      expect(stores.history, isEmpty);

      // First couple profile inherits legacy once, then legacy is gone.
      await stores.switchUser('khentsgdz');
      expect(stores.history.map((e) => e.title), ['Legacy Show']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('animex_watch_history_v1'), isNull);

      // Second profile (cinema or couple) starts from its own keys.
      await stores.switchUser('breyan');
      expect(stores.history, isEmpty);
    });
  });
}
