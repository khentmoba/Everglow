import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Watches `/version.json` (written by `tool/generate_sw.dart` at build time)
/// and flips [updateAvailable] when the live build differs from the one this
/// tab booted with. That keeps long-lived tabs from running a stale app
/// forever after a deploy.
///
/// Web only: [AppUpdateService] here is the real implementation; the native
/// stub in `app_update_service_native.dart` exposes the same API as a no-op.
class AppUpdateService extends ChangeNotifier {
  /// How often to re-check while the tab stays open.
  static const pollInterval = Duration(minutes: 15);

  bool _started = false;
  Timer? _timer;
  String? _bootBuild;
  String? _latestBuild;
  bool _dismissed = false;

  /// The build this tab booted with (null until the first fetch lands).
  String? get bootBuild => _bootBuild;

  /// The newest build seen on the server (null until the first fetch lands).
  String? get latestBuild => _latestBuild;

  /// True once the server serves a different build than the boot one
  /// (and the user has not dismissed this particular update).
  bool get updateAvailable =>
      _bootBuild != null &&
      _latestBuild != null &&
      _bootBuild != _latestBuild &&
      !_dismissed;

  /// Hides the banner for the currently known build. A newer build arriving
  /// later re-arms the prompt automatically.
  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  /// Starts polling. Safe to call more than once; later calls are ignored.
  Future<void> start() async {
    if (!kIsWeb || _started) return;
    _started = true;
    await checkNow();
    _timer ??= Timer.periodic(pollInterval, (_) => checkNow());
  }

  /// Fetches the live build stamp and notifies if it changed.
  Future<void> checkNow() async {
    final build = await fetchLiveBuild();
    if (build == null || build.isEmpty) return;
    _bootBuild ??= build;
    if (_latestBuild != build) {
      _latestBuild = build;
      // A brand-new build re-arms the prompt even after a dismiss.
      if (build != _bootBuild) _dismissed = false;
      notifyListeners();
    }
  }

  /// Reads `/version.json`, bypassing every cache layer. Returns null when
  /// offline or when the response is not parseable.
  Future<String?> fetchLiveBuild() async {
    try {
      final bust = DateTime.now().millisecondsSinceEpoch;
      final res = await http
          .get(
            Uri.parse('/version.json?t=$bust'),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return parseBuild(res.body);
    } catch (_) {
      return null;
    }
  }

  /// Pure parse helper, unit-tested: extracts the `build` stamp.
  static String? parseBuild(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final build = decoded['build'];
        if (build is String && build.isNotEmpty) return build;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
