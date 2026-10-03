import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:everglow/features/cinema/data/services/cinema_preferences.dart';

String _key(String user) => 'cinema_preferences_v1/$user';
String _values(bool hide, bool autoplay) =>
    jsonEncode({'hideSpoilers': hide, 'autoplayNext': autoplay});

class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences(Map<String, Object> values)
    : super.withData(
        values.map((key, value) => MapEntry('flutter.$key', value)),
      );
  final writeStarted = Completer<void>();
  final resumeWrite = Completer<void>();
  final writes = <String>[];
  int reads = 0;

  @override
  Future<Map<String, Object>> getAll() {
    reads++;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes.add(key);
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
      await resumeWrite.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CinemaPreferences preferences;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferences = CinemaPreferences();
  });
  tearDown(() async {
    await preferences.setUser('');
    preferences.dispose();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'defaults, both fields persist per profile, and logout is safe',
    () async {
      await preferences.setUser('demo-a');
      expect(preferences.hideSpoilers, isTrue);
      expect(preferences.autoplayNext, isFalse);
      await preferences.setHideSpoilers(false);
      await preferences.setAutoplayNext(true);
      await preferences.setUser('demo-b');
      expect(preferences.hideSpoilers, isTrue);
      expect(preferences.autoplayNext, isFalse);
      await preferences.setUser('demo-a');
      expect(preferences.hideSpoilers, isFalse);
      expect(preferences.autoplayNext, isTrue);
      await preferences.setUser('');
      await preferences.setHideSpoilers(false);
      await preferences.setAutoplayNext(true);
      expect(preferences.hideSpoilers, isTrue);
      expect(preferences.autoplayNext, isFalse);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString(_key('')), isNull);
      expect(stored.getString(_key('demo-a')), _values(false, true));
    },
  );

  test(
    'fresh instance reloads saved preferences and missing fields use defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        _key('demo-a'): '{"autoplayNext":true}',
      });
      await preferences.setUser('demo-a');
      expect(preferences.hideSpoilers, isTrue);
      expect(preferences.autoplayNext, isTrue);
      await preferences.setHideSpoilers(false);
      final restored = CinemaPreferences();
      await restored.setUser('demo-a');
      expect(restored.hideSpoilers, isFalse);
      expect(restored.autoplayNext, isTrue);
      restored.dispose();
    },
  );

  test('logout does not read SharedPreferences', () async {
    final platform = _DelayedPreferences({});
    SharedPreferencesStorePlatform.instance = platform;
    await preferences.setUser('');
    expect(platform.reads, 0);
  });

  test('pending profile load cannot publish after logout', () async {
    SharedPreferences.setMockInitialValues({
      _key('demo-a'): _values(false, true),
    });
    final loading = preferences.setUser('demo-a');
    await preferences.setUser('');
    await loading;
    expect(preferences.currentUser, isEmpty);
    expect(preferences.hideSpoilers, isTrue);
    expect(preferences.autoplayNext, isFalse);
  });

  test(
    'A-B-A only publishes the latest load, not old A with same name',
    () async {
      SharedPreferences.setMockInitialValues({
        _key('demo-a'): _values(false, true),
        _key('demo-b'): _values(true, false),
      });
      final published = <String>[];
      preferences.addListener(
        () => published.add(
          '${preferences.currentUser}/${preferences.hideSpoilers}/${preferences.autoplayNext}',
        ),
      );
      final first = preferences.setUser('demo-a');
      final middle = preferences.setUser('demo-b');
      final last = preferences.setUser('demo-a');
      published.clear();
      await Future.wait([first, middle, last]);
      expect(published, ['demo-a/false/true']);
    },
  );

  test('toggle during load preserves the other saved field', () async {
    SharedPreferences.setMockInitialValues({
      _key('demo-a'): _values(false, true),
    });
    final loading = preferences.setUser('demo-a');
    final writing = preferences.setHideSpoilers(true);
    await Future.wait([loading, writing]);
    expect(preferences.hideSpoilers, isTrue);
    expect(preferences.autoplayNext, isTrue);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(_key('demo-a')), _values(true, true));
  });

  test('superseded toggle cannot write B or stale A after A-B-A', () async {
    final a = _values(true, false);
    final b = _values(false, true);
    SharedPreferences.setMockInitialValues({
      _key('demo-a'): a,
      _key('demo-b'): b,
    });
    await preferences.setUser('demo-a');
    final writing = preferences.setHideSpoilers(false);
    final middle = preferences.setUser('demo-b');
    final last = preferences.setUser('demo-a');
    await Future.wait([writing, middle, last]);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(_key('demo-a')), a);
    expect(stored.getString(_key('demo-b')), b);
    expect(preferences.hideSpoilers, isTrue);
  });

  test(
    'already-started native write retains captured profile and values',
    () async {
      final b = _values(true, true);
      final platform = _DelayedPreferences({_key('demo-b'): b});
      SharedPreferencesStorePlatform.instance = platform;
      await preferences.setUser('demo-a');
      final writing = preferences.setHideSpoilers(false);
      await platform.writeStarted.future;
      await preferences.setUser('demo-b');
      platform.resumeWrite.complete();
      await writing;
      expect(platform.writes, ['flutter.${_key('demo-a')}']);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString(_key('demo-a')), _values(false, false));
      expect(stored.getString(_key('demo-b')), b);
      expect(preferences.hideSpoilers, isTrue);
      expect(preferences.autoplayNext, isTrue);
    },
  );

  test('slow native write cannot overwrite a newer toggle', () async {
    final platform = _DelayedPreferences({});
    SharedPreferencesStorePlatform.instance = platform;
    await preferences.setUser('demo-a');
    final first = preferences.setHideSpoilers(false);
    await platform.writeStarted.future;
    final second = preferences.setAutoplayNext(true);
    platform.resumeWrite.complete();
    await Future.wait([first, second]);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(_key('demo-a')), _values(false, true));
  });
}
