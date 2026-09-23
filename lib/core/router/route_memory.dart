import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last page Clair visited so a killed tab (or PWA) reopens
/// where she left off instead of the front gate.
///
/// How it fits together:
/// - `main.dart` awaits [load] before `runApp`, so the remembered page is
///   ready when the router is created.
/// - The router's `redirect` asks [bootRestoreTarget] once at boot: a bare
///   gateway (`/` with no query) sends her back to the remembered page —
///   directly when logged in, or via the login's `?from=` return hop when
///   logged out. Real links always win: any path, or any query (`?from=`,
///   `?dev=`, previews), skips the restore untouched.
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

  /// The restore runs once per boot: after the first redirect decision,
  /// later visits to the gateway stay on the gateway.
  static bool _consumed = false;

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

  /// Resets the one-shot guard. Tests only — production consumes once.
  @visibleForTesting
  static void debugResetConsume() {
    _consumed = false;
  }

  /// Takes the remembered page for the boot-time redirect decision.
  /// First call returns [bootLocation]; every later call returns null,
  /// so only the boot navigation restores — never later ones.
  static String? consumeBootLocation() {
    if (_consumed) return null;
    _consumed = true;
    return bootLocation;
  }

  /// Where the boot redirect should send a bare gateway (`/` with no
  /// query): the remembered page when logged in, the login's `?from=`
  /// return hop when logged out. Returns null when there is nothing to
  /// restore or the URL already carries intent (any path or any query).
  /// Cinema-only users never restore outside `/cinema`.
  static String? bootRestoreTarget({
    required bool authed,
    required bool cinemaOnly,
    required Uri uri,
    required String? remembered,
  }) {
    if (remembered == null) return null;
    if (uri.path != '/' || uri.queryParameters.isNotEmpty) return null;
    final safe = restorableOrNull(remembered);
    if (safe == null) return null;
    if (!authed) {
      return Uri(path: '/', queryParameters: {'from': safe}).toString();
    }
    if (cinemaOnly && !safe.startsWith('/cinema')) return '/cinema';
    return safe;
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
    _consumed = true; // this boot already decided; stay decided.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // A stale page on logout is harmless; the login flow decides home.
    }
  }
}
