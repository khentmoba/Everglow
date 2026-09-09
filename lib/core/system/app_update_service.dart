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
/// and moves the tab to the new build by itself, without Clair tapping
/// anything.
///
/// Slow-internet friendly by design:
/// - The check itself is tiny, skipped while offline, and also fires the
///   moment the tab becomes visible or the network returns — so the wait is
///   never longer than it has to be.
/// - When a new build is spotted, the new shell downloads silently in the
///   background (a plain fetch the service worker caches) while Clair keeps
///   using the old app. The reload after that is instant from cache instead
///   of a long splash on a slow line.
/// - Every build's shell URL is distinct (`?v=`), so a reload always boots
///   genuinely fresh bytes no matter which worker is active — the old
///   stable-filename setup could silently boot stale code after a deploy.
///
/// Switching policy ("silent when away, gentle when here"):
/// - Tab hidden (she switched apps — the common phone case): reloads in the
///   background. She just returns to the fresh app.
/// - Tab visible: a warm banner counts down 30s, then switches. "Later"
///   snoozes for 30 minutes.
/// - A playing `<video>` pauses the countdown entirely: movie night is never
///   interrupted. The tab still switches itself once hidden.
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

  /// How long "Later" hides the banner (and pauses every auto path).
  static const snoozeDuration = Duration(minutes: 30);

  /// Upper bound for the background shell download (slow phones on slow
  /// lines). Past this the tab switches anyway and streams like a first
  /// visit.
  static const warmTimeout = Duration(seconds: 150);

  /// Seconds of visible countdown before a tab in use switches itself.
  final int countdownTotal;

  final AppUpdateBrowser _browser;
  final http.Client _http;

  bool _started = false;
  bool _checking = false;
  Timer? _pollTimer;
  Timer? _tickTimer;
  String? _bootBuild;
  String? _latestBuild;
  bool _warming = false;
  bool _ready = false;
  int? _countdown;
  DateTime? _snoozedUntil;
  bool _applied = false;
  void Function()? _cancelListen;

  /// The build this tab booted with (null until the first fetch lands).
  String? get bootBuild => _bootBuild;

  /// The newest build seen on the server (null until the first fetch lands).
  String? get latestBuild => _latestBuild;

  /// True while the new shell downloads silently in the background.
  bool get warming => _warming;

  /// True once a newer build is downloaded and ready to switch to.
  bool get ready => _ready;

  /// Seconds left on the visible countdown, or null when the banner is
  /// static (video playing) or hidden.
  int? get countdownSeconds => _countdown;

  bool get snoozed =>
      _snoozedUntil != null && DateTime.now().isBefore(_snoozedUntil!);

  /// True when the banner should show: newer build ready, not snoozed,
  /// not already switching.
  bool get updateAvailable => _ready && !snoozed && !_applied;

  /// Starts polling. Safe to call more than once; later calls are ignored.
  /// No-op where the browser bridge is unsupported (native, VM tests
  /// without a fake).
  Future<void> start() async {
    if (!_browser.supported || _started) return;
    _started = true;
    _cancelListen = _browser.listen(
      onHidden: _maybeApplyInBackground,
      onVisible: () {
        // Returning to the tab: a deploy may have landed while away.
        unawaited(checkNow().then((_) => _evaluateAutoApply()));
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

  /// One step of the visible countdown. Called every second while counting;
  /// also the seam tests use instead of waiting on real timers.
  void tick() {
    final left = _countdown;
    if (left == null || _applied) return;
    if (snoozed || _browser.isVideoPlaying) {
      // She tapped Later, or pressed play mid-countdown: hold quietly.
      _stopCountdown();
      notifyListeners();
      return;
    }
    if (_browser.isHidden) {
      _stopCountdown();
      applyNow();
      return;
    }
    if (left <= 1) {
      _stopCountdown();
      applyNow();
      return;
    }
    _countdown = left - 1;
    notifyListeners();
  }

  /// Switches to the new build right now.
  void applyNow() {
    if (_applied) return;
    _applied = true;
    _stopCountdown();
    _pollTimer?.cancel();
    notifyListeners();
    _browser.reload();
  }

  /// Hides the banner for [snoozeDuration], pausing every auto path —
  /// including the background switch — until it expires. A still-newer
  /// build arriving later re-arms the prompt automatically.
  void snooze() {
    _snoozedUntil = DateTime.now().add(snoozeDuration);
    _stopCountdown();
    notifyListeners();
  }

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
    // A newer build re-arms the prompt even after a snooze.
    _snoozedUntil = null;
    _ready = false;
    _stopCountdown();
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
    _evaluateAutoApply();
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

  /// Decides what a ready tab does right now: background tabs switch at
  /// once, visible tabs count down unless a video is playing.
  void _evaluateAutoApply() {
    if (!_ready || snoozed || _applied) {
      _stopCountdown();
      notifyListeners();
      return;
    }
    if (_browser.isHidden) {
      _maybeApplyInBackground();
      return;
    }
    if (_browser.isVideoPlaying) {
      // Movie night: hold the countdown; the tab switches once hidden.
      _stopCountdown();
      notifyListeners();
      return;
    }
    _startCountdown();
    notifyListeners();
  }

  void _maybeApplyInBackground() {
    if (_ready && !snoozed && !_applied && _browser.isHidden) applyNow();
  }

  void _startCountdown() {
    if (_countdown != null) return;
    _countdown = countdownTotal;
    // The 1s ticker only exists while counting: no idle battery drain on
    // phones the other 99.9% of the time.
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopCountdown() {
    _countdown = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _resetUpdateState() {
    _ready = false;
    _stopCountdown();
    notifyListeners();
  }

  @visibleForTesting
  void debugExpireSnooze() {
    _snoozedUntil = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    try {
      _cancelListen?.call();
    } catch (_) {
      // The page may already be tearing down.
    }
    super.dispose();
  }
}
