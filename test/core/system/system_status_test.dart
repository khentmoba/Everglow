import 'package:everglow/core/system/system_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SystemStatus.fromJson maps the health contract', () {
    final status = SystemStatus.fromJson({
      'status': 'ok',
      'service': 'everglow-api',
      'version': '6.0.0+1',
      'time': '2026-08-14T00:00:00.000Z',
      'uptimeSeconds': 42,
      'checks': {'firestore': 'ok'},
    });

    expect(status.isHealthy, isTrue);
    expect(status.service, 'everglow-api');
    expect(status.version, '6.0.0+1');
    expect(status.uptimeSeconds, 42);
    expect(status.checks['firestore'], 'ok');
    expect(status.serverTime, isNotNull);
  });

  test('SystemStatus.unreachable is not healthy', () {
    final status = SystemStatus.unreachable(error: 'offline');
    expect(status.status, 'unreachable');
    expect(status.isHealthy, isFalse);
    expect(status.error, 'offline');
  });
}
