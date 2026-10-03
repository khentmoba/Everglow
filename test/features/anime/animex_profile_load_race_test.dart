import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:everglow/features/anime/data/services/animex_stores.dart';

const _historyKey = 'animex_watch_history_v1';
const _playlistsKey = 'animex_playlists_v1';
const _prefsKey = 'animex_prefs_v1';

String _history(String title) => json.encode([
  {
    'key': 'animex-120',
    'anilistId': 120,
    'malId': 53,
    'title': title,
    'coverUrl': '',
    'episode': 7,
    'totalEpisodes': 12,
    'updatedAt': DateTime(2026, 10, 1).millisecondsSinceEpoch,
  },
]);

Map<String, Object> _profile(String user, String title) => {
  '${_historyKey}_$user': _history(title),
  '${_playlistsKey}_$user': '[]',
  '${_prefsKey}_$user': json.encode({
    'titleJapanese': true,
    'hideSpoilers': false,
    'scheduleAlerts': {'demo-alert': true},
  }),
};

// Hold the first native write to exercise switches between _persist's awaits.
class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences(Map<String, Object> values)
    : super.withData(
        values.map((key, value) => MapEntry('flutter.$key', value)),
      );

  final writeStarted = Completer<void>();
  final resumeWrite = Completer<void>();
  final writes = <String>[];
  final removals = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes.add(key);
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
      await resumeWrite.future;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    removals.add(key);
    return super.remove(key);
  }
}

void main() {
  final stores = AnimexStores.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    stores.resetForTest();
  });

  tearDown(() {
    stores.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'old profile load cannot refill logged-out history or preferences',
    () async {
      SharedPreferences.setMockInitialValues(
        _profile('khentsgdz', 'Demo Khent'),
      );
      final loading = stores.load(username: 'khentsgdz');
      await stores.switchUser(null);
      expect(stores.currentUser, isEmpty);
      expect(stores.hideSpoilers, isTrue);
      await loading;
      expect(stores.currentUser, isEmpty);
      expect(stores.history, isEmpty);
      expect(stores.playlists, isEmpty);
      expect(stores.hideSpoilers, isTrue);
      expect(stores.titleJapanese, isFalse);
      expect(stores.isAlertEnabled('demo-alert'), isFalse);
    },
  );

  test('superseded load never starts legacy migration', () async {
    final legacy = {
      _historyKey: _history('Demo Legacy'),
      _prefsKey: json.encode({'hideSpoilers': false}),
    };
    SharedPreferences.setMockInitialValues(legacy);
    final loading = stores.load(username: 'khentsgdz');
    await stores.switchUser(null);
    await loading;
    expect(stores.history, isEmpty);
    expect(stores.hideSpoilers, isTrue);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in legacy.entries) {
      expect(prefs.getString(entry.key), entry.value);
    }
    expect(prefs.getString('${_historyKey}_khentsgdz'), isNull);
  });

  test('A to B to A only publishes the newest load, not old A or B', () async {
    SharedPreferences.setMockInitialValues({
      ..._profile('khentsgdz', 'Demo Khent'),
      ..._profile('clairjassen', 'Demo Clair'),
    });
    final published = <List<String>>[];
    void listener() =>
        published.add(stores.history.map((e) => e.title).toList());
    stores.addListener(listener);
    addTearDown(() => stores.removeListener(listener));
    final first = stores.load(username: 'khentsgdz');
    final middle = stores.switchUser('clairjassen');
    final last = stores.switchUser('khentsgdz');
    published.clear(); // Ignore the synchronous empty state on each switch.
    await Future.wait([first, middle, last]);
    expect(stores.currentUser, 'khentsgdz');
    expect(stores.history.single.title, 'Demo Khent');
    expect(published, [
      <String>['Demo Khent'],
    ]);
  });

  test('persist awaiting preferences cannot write the next profile', () async {
    final clair = _profile('clairjassen', 'Demo Clair');
    SharedPreferences.setMockInitialValues(clair);
    await stores.load(username: 'khentsgdz');
    final writing = stores.setHideSpoilers(false);
    final switching = stores.switchUser('clairjassen');
    await Future.wait([writing, switching]);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in clair.entries) {
      expect(prefs.getString(entry.key), entry.value);
    }
    expect(prefs.getString('${_prefsKey}_khentsgdz'), isNull);
    expect(stores.history.single.title, 'Demo Clair');
  });

  test(
    'persist is superseded even after switching back to its original user',
    () async {
      final khent = {
        ..._profile('khentsgdz', 'Demo Khent'),
        '${_prefsKey}_khentsgdz': json.encode({'hideSpoilers': true}),
      };
      SharedPreferences.setMockInitialValues({
        ...khent,
        ..._profile('clairjassen', 'Demo Clair'),
      });
      await stores.load(username: 'khentsgdz');
      final writing = stores.setHideSpoilers(false);
      final middle = stores.switchUser('clairjassen');
      final last = stores.switchUser('khentsgdz');
      await Future.wait([writing, middle, last]);
      expect(stores.currentUser, 'khentsgdz');
      expect(stores.hideSpoilers, isTrue);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in khent.entries) {
        expect(prefs.getString(entry.key), entry.value);
      }
    },
  );

  test(
    'switch during a native write cancels remaining old-profile writes',
    () async {
      final clair = _profile('clairjassen', 'Demo Clair');
      final platform = _DelayedPreferences(clair);
      SharedPreferencesStorePlatform.instance = platform;
      await stores.load(username: 'khentsgdz');
      final writing = stores.setHideSpoilers(false);
      await platform.writeStarted.future;
      await stores.switchUser('clairjassen');
      platform.resumeWrite.complete();
      await writing;
      expect(platform.writes, ['flutter.${_historyKey}_khentsgdz']);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in clair.entries) {
        expect(prefs.getString(entry.key), entry.value);
      }
      expect(prefs.getString('${_prefsKey}_khentsgdz'), isNull);
    },
  );

  test('logout during migration keeps legacy data and safe defaults', () async {
    final legacy = {
      _historyKey: _history('Demo Legacy'),
      _prefsKey: json.encode({'hideSpoilers': false}),
    };
    final platform = _DelayedPreferences(legacy);
    SharedPreferencesStorePlatform.instance = platform;
    final loading = stores.load(username: 'khentsgdz');
    await platform.writeStarted.future;
    await stores.switchUser(null);
    platform.resumeWrite.complete();
    await loading;
    expect(stores.currentUser, isEmpty);
    expect(stores.history, isEmpty);
    expect(stores.hideSpoilers, isTrue);
    expect(platform.writes, ['flutter.${_historyKey}_khentsgdz']);
    expect(platform.removals, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in legacy.entries) {
      expect(prefs.getString(entry.key), entry.value);
    }
  });
}
