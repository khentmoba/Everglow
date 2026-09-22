import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/logger.dart';
import 'app_update_browser.dart';

/// What one `/version.json` read says: the live build stamp plus the
/// version-busted core-shell URL (`main.dart.js?v=...`, stamped by
/// `tool/build_web.dart`). Older deploys omit `core`.
typedef LiveBuild = ({String build, String? core});

/// Watches `/version.json` (written by `tool/generate_sw.dart` at build time)
/// and informs the user with a gentle notification when a new build is ready.
///
/// Slow-internet friendly and user-controlled by design:
/// - The check itself is tiny, skipped while offline, and also fires the
///   moment the tab becomes visible or the network returns — so the wait is
///   never longer than it has to be.
/// - When a new build is spotted, the new shell downloads silently in the
///   background (a plain fetch the service worker caches) while Clair keeps
///   using the old app. The reload after that is instant from cache instead
///   of a long splash on a slow line.
/// - Never forcefully restarts! No auto-switch timers, no sudden reloads while
///   watching anime or typing, and no background reloads when switching tabs.
/// - The user sees a warm notification banner where they can tap "Restart" to
///   switch right away, or tap dismiss and reload manually whenever they like.
///
/// All browser access goes through [AppUpdateBrowser] (real on web, no-op
/// stub elsewhere), so this file stays unit-testable on the VM.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    AppUpdateBrowser? browser,
    http.Client? httpClient,
    this.countdownTotal = 30,
  })  : _browser = browser ?? AppUpdateBrowser.instance,
        _http = httpClient ?? http.Client();

  /// How often to re-check while the tab stays open.
  static const pollInterval = Duration(minutes: 15);

  /// Upper bound for the background shell download (slow phones on slow
  /// lines). Past this the tab switches anyway and streams like a first
  /// visit.
  static const warmTimeout = Duration(seconds: 150);

  /// Retained for backwards compatibility.
  final int countdownTotal;

  final AppUpdateBrowser _browser;
  final http.Client _http;

  bool _started = false;
  bool _checking = false;
  Timer? _pollTimer;
  String? _bootBuild;
  String? _latestBuild;
  String? _dismissedBuild;
  bool _warming = false;
  bool _ready = false;
  bool _applied = false;
  void Function()? _cancelListen;

  /// The build this tab booted with (null until the first fetch lands).
  String? get bootBuild => _bootBuild;

  /// The newest build seen on the server (null until the first fetch lands).
  String? get latestBuild => _latestBuild;

  /// The build dismissed by the user, if any.
  String? get dismissedBuild => _dismissedBuild;

  /// True while the new shell downloads silently in the background.
  bool get warming => _warming;

  /// True once a newer build is downloaded and ready to switch to.
  bool get ready => _ready;

  /// True if the user dismissed the notification for the newest build.
  bool get isDismissed =>
      _dismissedBuild != null && _dismissedBuild == _latestBuild;

  /// Retained for backwards compatibility; returns null since countdowns are removed.
  int? get countdownSeconds => null;

  /// Retained for backwards compatibility; mirrors [isDismissed].
  bool get snoozed => isDismissed;

  /// True when the banner should show: newer build ready, not dismissed,
  /// not already switching.
  bool get updateAvailable => _ready && !isDismissed && !_applied;

  /// Starts polling. Safe to call more than once; later calls are ignored.
  /// No-op where the browser bridge is unsupported (native, VM tests
  /// without a fake).
  Future<void> start() async {
    if (!_browser.supported || _started) return;
    _started = true;
    _cancelListen = _browser.listen(
      onHidden: () {
        // Tab hidden: never auto-reload, so movies, anime, music, or forms
        // are never interrupted.
      },
      onVisible: () {
        // Returning to the tab: a deploy may have landed while away.
        unawaited(checkNow());
      },
      onOnline: () => unawaited(checkNow()),
    );
    await checkNow();
    _pollTimer ??= Timer.periodic(pollInterval, (_) => checkNow());
  }

  /// Fetches the live build stamp and warms the new shell when it changed.
  /// Single-flight and skipped while offline, so slow lines never stack up
  /// parallel checks.
  Future<void> checkNow() async {
    if (_checking || _applied) return;
    if (_browser.isOffline) return;
    _checking = true;
    try {
      final live = await fetchLiveBuild();
      await noteLiveBuild(live?.build, live?.core);
    } finally {
      _checking = false;
    }
  }

  /// Records what the server said and warms the new shell when it differs
  /// from the boot build. The seam tests use instead of real HTTP.
  Future<void> noteLiveBuild(String? build, [String? core]) async {
    if (build == null || build.isEmpty || _applied) return;
    _bootBuild ??= build;
    if (build == _latestBuild) return;
    _latestBuild = build;
    if (build == _bootBuild) {
      // First check, or a rollback: nothing newer to switch to.
      _resetUpdateState();
    } else {
      await _warmAndReady(core);
    }
  }

  /// Retained for backwards compatibility (no-op since auto-countdown is removed).
  void tick() {}

  /// Switches to the new build right now.
  void applyNow() {
    if (_applied) return;
    _applied = true;
    _pollTimer?.cancel();
    notifyListeners();
    _browser.reload();
  }

  /// Dismisses the notification for the current update.
  /// The user can continue using the site undisturbed and reload manually on their own.
  void dismiss() {
    _dismissedBuild = _latestBuild;
    notifyListeners();
  }

  /// Alias for [dismiss] for backwards compatibility.
  void snooze() => dismiss();

  /// Reads `/version.json`, bypassing every cache layer. Returns null when
  /// offline or when the response is not parseable.
  Future<LiveBuild?> fetchLiveBuild() async {
    if (_browser.isOffline) return null;
    try {
      final bust = DateTime.now().millisecondsSinceEpoch;
      final res = await _http
          .get(
            Uri.parse('/version.json?t=$bust'),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final build = parseBuild(res.body);
      if (build == null) return null;
      return (build: build, core: parseCore(res.body));
    } catch (_) {
      return null;
    }
  }

  /// Pure parse helpers, unit-tested: extract the `build` stamp and the
  /// version-busted core-shell URL.
  static String? parseBuild(String body) => _parseField(body, 'build');
  static String? parseCore(String body) => _parseField(body, 'core');

  static String? _parseField(String body, String field) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded[field];
        if (value is String && value.isNotEmpty) return value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the new shell now so the switch is instant, while Clair keeps
  /// using the old app. Just a plain fetch: the service worker caches the
  /// version-busted URL on its way through. Best-effort — without a `core`
  /// URL (older deploys) or on failure, the tab still switches, it just
  /// streams like a first visit.
  Future<void> _warmAndReady(String? core) async {
    if (_warming || _applied) return;
    _ready = false;
    _warming = true;
    notifyListeners();
    var warmed = false;
    try {
      warmed = core != null && await _warmCore(core);
    } catch (_) {
      warmed = false;
    } finally {
      _warming = false;
    }
    if (_applied) return;
    // The warm always targets the live shell URL, so whatever is newest
    // now — even a deploy that landed mid-warm — is the ready one.
    if (_latestBuild != null && _latestBuild != _bootBuild) {
      _ready = true;
      Logger.i('Everglow update ready ($_latestBuild, pre-warmed: $warmed)');
    }
    notifyListeners();
  }

  Future<bool> _warmCore(String core) async {
    try {
      final res = await _http.get(Uri.parse(core)).timeout(warmTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _resetUpdateState() {
    _ready = false;
    notifyListeners();
  }

  @visibleForTesting
  void debugResetDismissal() {
    _dismissedBuild = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    try {
      _cancelListen?.call();
    } catch (_) {
      // The page may already be tearing down.
    }
    super.dispose();
  }
}
