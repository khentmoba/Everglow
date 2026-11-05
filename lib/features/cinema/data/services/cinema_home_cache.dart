import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../models/media_item.dart';

/// Last good Cinema Home rows, kept on this device.
///
/// A repeat open paints these while the TMDB refresh runs behind them. The
/// rows are public catalogue data, the same for every profile, so one copy
/// serves everyone on the device.
class CinemaHomeCache {
  CinemaHomeCache._();

  static const _prefsKey = 'cinema_home_rows_v1';

  /// Rows already read or written this app session. A repeat open reads them
  /// without awaiting storage, so its first frame already has titles.
  static Map<String, List<MediaItem>>? _session;

  /// When the saved rows were last confirmed against TMDB.
  static DateTime? _savedAt;

  /// Rows usable right now without awaiting storage.
  static Map<String, List<MediaItem>>? get session => _session;

  /// True when the saved rows are recent enough to show without asking TMDB
  /// again. A cache saved by an older build has no timestamp, so it counts as
  /// stale and gets refreshed once.
  static bool isFresh(Duration window) {
    final savedAt = _savedAt;
    if (_session == null || savedAt == null) return false;
    return DateTime.now().difference(savedAt) < window;
  }

  /// Saved rows, or null when nothing usable is stored.
  static Future<Map<String, List<MediaItem>>?> read() async {
    if (_session != null) return _session;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      // Current shape is {savedAt, rows}. Anything else is an older save
      // without a timestamp, which is read as stale on purpose.
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

  /// Saves every Home row as it stands. An empty row (a failed refresh) keeps
  /// the copy saved before it, so a bad network never wipes the screen.
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

  /// Loads the saved rows into memory at app start, so the first Cinema open
  /// of a session paints rows on its first frame instead of after a disk read.
  static Future<void> warm() async {
    await read();
  }

  /// Test helper: forgets the in-session copy, as an app restart would.
  @visibleForTesting
  static void resetForTests() {
    _session = null;
    _savedAt = null;
  }

  /// Test helper: ages the saved rows so the freshness window can be tested
  /// without waiting ten minutes.
  @visibleForTesting
  static void debugAgeRows(Duration age) {
    _savedAt = DateTime.now().subtract(age);
  }
}
