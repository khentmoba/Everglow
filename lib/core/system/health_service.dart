import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'system_status.dart';

typedef ConnectivityCheck = bool Function();

/// Lightweight backend health probe used during app startup.
///
/// The probe is intentionally non-blocking in the UI path: a failed or
/// slow check degrades to [SystemStatus.unreachable] instead of delaying
/// the first frame.
class HealthService {
  HealthService({
    http.Client? client,
    Uri? endpoint,
    ConnectivityCheck? isOnline,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? Uri.base.resolve('/api/health'),
       _isOnline = isOnline ?? _alwaysOnline;

  final http.Client _client;
  final Uri _endpoint;
  final ConnectivityCheck _isOnline;

  Future<SystemStatus> probe({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final online = _isOnline();
    try {
      final response = await _client.get(_endpoint).timeout(timeout);
      if (response.statusCode != 200) {
        return SystemStatus.unreachable(
          error: 'Backend health endpoint returned HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return SystemStatus.unreachable(
          error: 'Backend health endpoint returned an invalid payload',
        );
      }
      return SystemStatus.fromJson(decoded);
    } catch (e) {
      return SystemStatus.unreachable(
        error: online ? e.toString() : 'Client is offline',
      );
    }
  }

  void dispose() {
    _client.close();
  }

  static bool _alwaysOnline() => true;
}
