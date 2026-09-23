import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last page Clair visited so a killed tab (or PWA) reopens
/// where she left off instead of the front gate.
///
/// How it fits together:
/// - `main.dart` awaits [load] before `runApp`, so the remembered page is
///   ready when the router is created.
/// - The router uses [bootLocation] as its `initialLocation`. go_router
///   only honors that when the browser URL is exactly `/`, so real links
///   always win: any path or query (`?from=`, `?dev=`, previews, deep
///   links) skips the restore untouched. Logged-out boots land on the
///   remembered page and bounce through the usual `?from=` login hop.
/// - Every navigation is recorded via [remember] (wired to the router
///   delegate listener), so the saved page is always the latest one.
///
/// Only reload-safe pages are kept: the gateway itself (login has its own
/// `?from=` return flow) and routes that need an in-memory `extra` payload
/// (reader, game boards, watch party) are never saved — reopening those
/// would land on the error page instead.
class RouteMemory {
  RouteMemory._();

  @visibleForTesting
  static const storageKey = 'route_memory:last_location';

  /// Pages that need an in-memory `extra` object and show the error page
  /// on a plain reload. Compared against the URI path (no query).
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
    '/watch-party',
  };

  /// The remembered page to boot into, loaded by [load] before `runApp`.
  static String? bootLocation;

  /// Reads the saved page from the device. Never throws — a failure just
  /// means a normal boot into the gateway.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bootLocation = restorableOrNull(prefs.getString(storageKey));
    } catch (_) {
      bootLocation = null;
    }
  }

  /// Records [location] as the latest page. Fire-and-forget: navigation
  /// never waits for the write, and unsafe pages are silently skipped.
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

  /// Returns [location] when it is safe to reopen after a restart
  /// (internal path, not the gateway, no `extra` needed), else null.
  /// The full string (including query) is kept so parameterized pages
  /// like `/cinema/video/123?title=Foo` reopen exactly.
  static String? restorableOrNull(String? location) {
    if (location == null || location.isEmpty) return null;
    // Check the raw value: Uri parsing already resolves `/a/../b` into
    // `/b`, so the parsed path can never be trusted for this test.
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

  /// Clears the remembered page (logout). Best-effort, never throws.
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
