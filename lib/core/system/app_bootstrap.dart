import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '../services/notification_service.dart';
import '../utils/logger.dart';
import 'app_version.dart';
import 'system_status.dart';

typedef FirebaseInitializer = Future<void> Function();
typedef EnvLoader = Future<void> Function();
typedef HealthProbe = Future<SystemStatus> Function();
typedef NotificationsInitializer = Future<void> Function();
typedef FirestoreConfigurer = Future<void> Function();
typedef UrlStrategyConfigurer = void Function();

/// Immutable summary of the startup sequence.
///
/// [health] is the instant snapshot (`checking` while the probe runs — the
/// probe never blocks [AppBootstrap.run]); await [healthFuture] for the
/// probed backend status.
class BootstrapResult {
  final bool environmentLoaded;
  final SystemStatus health;
  final Future<SystemStatus> healthFuture;
  final Duration elapsed;

  const BootstrapResult({
    required this.environmentLoaded,
    required this.health,
    required this.healthFuture,
    required this.elapsed,
  });

  bool get isHealthy => health.isHealthy;
}

/// Deterministic startup orchestrator for Everglow.
///
/// Dependencies are injected so the sequence is testable without Firebase
/// plugins. Production wiring lives in `main.dart`; unit tests inject fakes.
class AppBootstrap {
  AppBootstrap({
    required FirebaseInitializer initializeFirebase,
    EnvLoader? loadEnvironment,
    HealthProbe? probeHealth,
    NotificationsInitializer? initializeNotifications,
    FirestoreConfigurer? configureFirestore,
    UrlStrategyConfigurer? configureUrlStrategy,
    this.scaffoldMessengerKey,
    this.firestoreCacheSizeBytes = 100 * 1024 * 1024,
  }) : _initializeFirebase = initializeFirebase,
       _loadEnvironment = loadEnvironment,
       _probeHealth = probeHealth,
       _initializeNotifications = initializeNotifications,
       _configureFirestore = configureFirestore,
       _configureUrlStrategy = configureUrlStrategy;

  final FirebaseInitializer _initializeFirebase;
  final EnvLoader? _loadEnvironment;
  final HealthProbe? _probeHealth;
  final NotificationsInitializer? _initializeNotifications;
  final FirestoreConfigurer? _configureFirestore;
  final UrlStrategyConfigurer? _configureUrlStrategy;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final int firestoreCacheSizeBytes;

  Future<BootstrapResult> run() async {
    final stopwatch = Stopwatch()..start();

    WidgetsFlutterBinding.ensureInitialized();
    (_configureUrlStrategy ?? usePathUrlStrategy)();

    var environmentLoaded = false;
    try {
      await (_loadEnvironment ?? () async {})();
      environmentLoaded = true;
    } catch (e) {
      Logger.w('Environment load failed: $e');
    }

    await _initializeFirebase();

    await (_configureFirestore ?? _defaultFirestoreSettings)();

    final messengerKey = scaffoldMessengerKey;
    if (messengerKey != null) {
      NotificationService.setScaffoldMessengerKey(messengerKey);
    }

    // Push notification setup is non-critical; never block first frame.
    unawaited(_startNotifications());

    // Backend health never blocks the first frame: the probe runs in the
    // background (like notifications) and its result lands on healthFuture.
    final healthFuture = _probeHealthInBackground(_probeHealth);

    stopwatch.stop();
    Logger.i(
      'Everglow ${AppVersion.current} booted in '
      '${stopwatch.elapsedMilliseconds}ms',
    );
    return BootstrapResult(
      environmentLoaded: environmentLoaded,
      health: const SystemStatus(status: 'checking'),
      healthFuture: healthFuture,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Runs the health probe to completion without ever throwing: failures
  /// degrade to [SystemStatus.unreachable] instead of failing startup.
  Future<SystemStatus> _probeHealthInBackground(HealthProbe? probe) async {
    if (probe == null) {
      return SystemStatus.unreachable(error: 'Health probe not configured');
    }
    try {
      return await probe();
    } catch (e) {
      return SystemStatus.unreachable(error: e.toString());
    }
  }

  Future<void> _startNotifications() async {
    try {
      await (_initializeNotifications ?? () async {})();
    } catch (e) {
      Logger.w('Push notification init failed: $e');
    }
  }

  Future<void> _defaultFirestoreSettings() {
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: firestoreCacheSizeBytes,
    );
    return Future.value();
  }
}
