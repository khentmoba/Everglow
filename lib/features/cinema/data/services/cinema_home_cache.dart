import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../models/media_item.dart';

/// Last good Cinema Home rows, kept on this device.
///
/// A repeat open paints these while the TMDB refresh runs behind them. The
/// rows are public catalogue data, the same for every profile, so one copy
/// serves everyone on the device. Agent demo rows never reach this store.
class CinemaHomeCache {
  CinemaHomeCache._();

  static const _prefsKey = 'cinema_home_rows_v1';

  /// Rows already read or written this app session. A repeat open reads them
  /// without awaiting storage, so its first frame already has titles.
  static Map<String, List<MediaItem>>? _session;

  /// Rows usable right now without awaiting storage.
  static Map<String, List<MediaItem>>? get session => _session;

  /// Saved rows, or null when nothing usable is stored.
  static Future<Map<String, List<MediaItem>>?> read() async {
    if (_session != null) return _session;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rows = <String, List<MediaItem>>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! List) continue;
        rows[key] = [
          for (final item in value)
            if (item is Map<String, dynamic>) MediaItem.fromJson(item),
        ];
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
      _session = merged;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final entry in merged.entries)
            entry.key: [for (final item in entry.value) item.toJson()],
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
  static void resetForTests() => _session = null;
}
