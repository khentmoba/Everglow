import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// Last-known-good rows for the anime home screen.
///
/// The home page is the first thing users see, so when AniList/Jikan/TMDB
/// are all unreachable we still show the most recent successful fetch
/// instead of a blank page. Rows are keyed by their home-row id and only
/// replaced after a successful network fetch, so cached data is never
/// overwritten with an empty failure result.
class AnimexHomeCache {
  AnimexHomeCache._internal();

  static final AnimexHomeCache instance = AnimexHomeCache._internal();

  static const _cacheKey = 'animex_home_rows_v1';

  Map<String, List<MediaItem>> _rows = {};
  bool _loaded = false;

  Future<Map<String, List<MediaItem>>> load() async {
    if (_loaded) return Map.unmodifiable(_rows);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final rows = <String, List<MediaItem>>{};
        for (final entry in decoded.entries) {
          final list = (entry.value as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MediaItem.fromJson)
              .toList();
          if (list.isNotEmpty) rows[entry.key] = list;
        }
        _rows = rows;
      }
      _loaded = true;
    } catch (e) {
      debugPrint('[AnimexHomeCache] load failed: $e');
    }
    return Map.unmodifiable(_rows);
  }

  Future<void> saveRow(String id, List<MediaItem> items) async {
    if (items.isEmpty) return;
    _rows[id] = List.of(items);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        json.encode({
          for (final e in _rows.entries) e.key: e.value.map((i) => i.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('[AnimexHomeCache] save failed: $e');
    }
  }
}
