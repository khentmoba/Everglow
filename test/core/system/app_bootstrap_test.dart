import 'package:everglow/core/system/app_bootstrap.dart';
import 'package:everglow/core/system/system_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('run reports environment load and backend health', () async {
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
    expect(result.isHealthy, isTrue);
    expect(result.elapsed, isNotNull);
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
    expect(result.health.status, 'unreachable');
  });
}
