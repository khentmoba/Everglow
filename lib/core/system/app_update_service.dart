import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/logger.dart';
import 'app_update_browser.dart';

typedef LiveBuild = ({String build, String? core});

class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    AppUpdateBrowser? browser,
    http.Client? httpClient,
    this.countdownTotal = 30,
  })  : _browser = browser ?? AppUpdateBrowser.instance,
        _http = httpClient ?? http.Client();

  static const pollInterval = Duration(minutes: 15);

  static const warmTimeout = Duration(seconds: 150);

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

  String? get bootBuild => _bootBuild;

  String? get latestBuild => _latestBuild;

  String? get dismissedBuild => _dismissedBuild;

  bool get warming => _warming;

  bool get ready => _ready;

  bool get isDismissed =>
      _dismissedBuild != null && _dismissedBuild == _latestBuild;

  int? get countdownSeconds => null;

  bool get snoozed => isDismissed;

  bool get updateAvailable => _ready && !isDismissed && !_applied;

  Future<void> start() async {
    if (!_browser.supported || _started) return;
    _started = true;
    _cancelListen = _browser.listen(
      onHidden: () {
      },
      onVisible: () {
        unawaited(checkNow());
      },
      onOnline: () => unawaited(checkNow()),
    );
    await checkNow();
    _pollTimer ??= Timer.periodic(pollInterval, (_) => checkNow());
  }

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

  Future<void> noteLiveBuild(String? build, [String? core]) async {
    if (build == null || build.isEmpty || _applied) return;
    _bootBuild ??= build;
    if (build == _latestBuild) return;
    _latestBuild = build;
    if (build == _bootBuild) {
      _resetUpdateState();
    } else {
      await _warmAndReady(core);
    }
  }

  void tick() {}

  void applyNow() {
    if (_applied) return;
    _applied = true;
    _pollTimer?.cancel();
    notifyListeners();
    _browser.reload();
  }

  void dismiss() {
    _dismissedBuild = _latestBuild;
    notifyListeners();
  }

  void snooze() => dismiss();

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
