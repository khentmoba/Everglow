import 'dart:async';

import 'package:everglow/core/system/app_bootstrap.dart';
import 'package:everglow/core/system/system_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('run reports environment load and eventual backend health', () async {
    var firebaseInitialized = false;
    var environmentLoaded = false;
    final bootstrap = AppBootstrap(
      loadEnvironment: () async {
        environmentLoaded = true;
      },
      initializeFirebase: () async {
        firebaseInitialized = true;
      },
      configureFirestore: () async {},
      configureUrlStrategy: () {},
      initializeNotifications: () async {},
      probeHealth: () async => SystemStatus.fromJson({
        'status': 'ok',
        'service': 'everglow-api',
        'version': '6.0.0+1',
        'time': '2026-08-14T00:00:00.000Z',
        'uptimeSeconds': 1,
        'checks': {'firestore': 'ok'},
      }),
    );

    final result = await bootstrap.run();

    expect(firebaseInitialized, isTrue);
    expect(environmentLoaded, isTrue);
    expect(result.environmentLoaded, isTrue);
    expect(result.health.status, 'checking');
    expect(result.elapsed, isNotNull);
    final probed = await result.healthFuture;
    expect(probed.isHealthy, isTrue);
    expect(probed.status, 'ok');
  });

  test('run tolerates a failing health probe', () async {
    final bootstrap = AppBootstrap(
      initializeFirebase: () async {},
      configureFirestore: () async {},
      configureUrlStrategy: () {},
      initializeNotifications: () async {},
      probeHealth: () async => throw Exception('probe exploded'),
    );

    final result = await bootstrap.run();

    expect(result.environmentLoaded, isTrue);
    expect(result.isHealthy, isFalse);
    expect(result.health.status, 'checking');
    final probed = await result.healthFuture;
    expect(probed.isHealthy, isFalse);
    expect(probed.status, 'unreachable');
  });

  test('run does not wait for a slow health probe', () async {
    final probeGate = Completer<SystemStatus>();
    final bootstrap = AppBootstrap(
      initializeFirebase: () async {},
      configureFirestore: () async {},
      configureUrlStrategy: () {},
      initializeNotifications: () async {},
      probeHealth: () => probeGate.future,
    );

    // run() must return while the probe is still pending.
    final result = await bootstrap.run();
    expect(result.health.status, 'checking');

    probeGate.complete(SystemStatus.unreachable(error: 'slow network'));
    final probed = await result.healthFuture;
    expect(probed.status, 'unreachable');
  });
}
