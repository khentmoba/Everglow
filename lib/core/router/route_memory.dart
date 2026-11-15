import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteMemory {
  RouteMemory._();

  @visibleForTesting
  static const storageKey = 'route_memory:last_location';

  static const extraOnlyPaths = {
    '/academy/solo',
    '/academy/match',
    '/academy/podium',
    '/books/reader',
    '/books/detail',
    '/books/listen',
    '/books/list',
    '/books/category',
    '/manga/reader',
  };

  static String? bootLocation;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bootLocation = restorableOrNull(prefs.getString(storageKey));
    } catch (_) {
      bootLocation = null;
    }
  }

  static Future<void> remember(String location) async {
    final safe = restorableOrNull(location);
    if (safe == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, safe);
    } catch (_) {
      // A missed write only costs one restore; never break navigation.
    }
  }

  static String? restorableOrNull(String? location) {
    if (location == null || location.isEmpty) return null;
    if (location.contains('..')) return null;
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    if (uri.hasScheme || uri.hasAuthority) return null;
    final path = uri.path;
    if (path.isEmpty || path == '/') return null;
    if (path.contains('..') || path.startsWith('//')) return null;
    if (extraOnlyPaths.contains(path)) return null;
    return location;
  }

  static Future<void> clear() async {
    bootLocation = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // A stale page on logout is harmless; the login flow decides home.
    }
  }
}
