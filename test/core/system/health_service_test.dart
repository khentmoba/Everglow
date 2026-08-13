import 'package:everglow/core/system/health_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final endpoint = Uri.parse('https://everglow-1c6db.web.app/api/health');

  test('probe returns a healthy status from /api/health', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/health');
      return http.Response(
        '{"status":"ok","service":"everglow-api","version":"6.0.0+1",'
        '"time":"2026-08-14T00:00:00.000Z","uptimeSeconds":12,'
        '"checks":{"firestore":"ok"}}',
        200,
      );
    });
    final service = HealthService(client: client, endpoint: endpoint);

    final status = await service.probe();

    expect(status.isHealthy, isTrue);
    expect(status.service, 'everglow-api');
    expect(status.checks['firestore'], 'ok');
  });

  test('probe degrades gracefully on a network error', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    final service = HealthService(
      client: client,
      endpoint: endpoint,
      isOnline: () => false,
    );

    final status = await service.probe();

    expect(status.status, 'unreachable');
    expect(status.isHealthy, isFalse);
    expect(status.error, 'Client is offline');
  });

  test('probe degrades gracefully on a non-200 response', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    final service = HealthService(client: client, endpoint: endpoint);

    final status = await service.probe();

    expect(status.status, 'unreachable');
    expect(status.error, contains('503'));
  });
}
