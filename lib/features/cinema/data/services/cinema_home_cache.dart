import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../models/media_item.dart';

class CinemaHomeCache {
  CinemaHomeCache._();

  static const _prefsKey = 'cinema_home_rows_v1';

  static Map<String, List<MediaItem>>? _session;

  static DateTime? _savedAt;

  static Map<String, List<MediaItem>>? get session => _session;

  static bool isFresh(Duration window) {
    final savedAt = _savedAt;
    if (_session == null || savedAt == null) return false;
    return DateTime.now().difference(savedAt) < window;
  }

  static Future<Map<String, List<MediaItem>>?> read() async {
    if (_session != null) return _session;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final stored = decoded['rows'];
      final rowsJson = stored is Map ? stored : decoded;
      final savedAtMs = decoded['savedAt'];

      final rows = <String, List<MediaItem>>{};
      for (final entry in rowsJson.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! List) continue;
        rows[key] = [
          for (final item in value)
            if (item is Map<String, dynamic>) MediaItem.fromJson(item),
        ];
      }
      if (savedAtMs is int) {
        _savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      }
      return _session ??= rows;
    } catch (e, st) {
      Logger.e('Cinema: home cache read failed', error: e, stackTrace: st);
      return null;
    }
  }

  static Future<void> save(Map<String, List<MediaItem>> liveRows) async {
    try {
      final saved = await read() ?? const <String, List<MediaItem>>{};
      final merged = <String, List<MediaItem>>{
        ...saved,
        for (final entry in liveRows.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };
      if (merged.isEmpty) return;
      final savedAt = DateTime.now();
      _session = merged;
      _savedAt = savedAt;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'savedAt': savedAt.millisecondsSinceEpoch,
          'rows': {
            for (final entry in merged.entries)
              entry.key: [for (final item in entry.value) item.toJson()],
          },
        }),
      );
    } catch (e, st) {
      Logger.e('Cinema: home cache save failed', error: e, stackTrace: st);
    }
  }

  static Future<void> warm() async {
    await read();
  }

  @visibleForTesting
  static void resetForTests() {
    _session = null;
    _savedAt = null;
  }

  @visibleForTesting
  static void debugAgeRows(Duration age) {
    _savedAt = DateTime.now().subtract(age);
  }
}
