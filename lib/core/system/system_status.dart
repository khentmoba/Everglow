/// Result of probing the backend health endpoint.
///
/// `status` mirrors the Cloud Function response: `ok`, `degraded`, or
/// `unreachable` when the client could not reach the API at all.
class SystemStatus {
  final String status;
  final String? service;
  final String? version;
  final DateTime? checkedAt;
  final DateTime? serverTime;
  final int? uptimeSeconds;
  final Map<String, String> checks;
  final String? error;

  const SystemStatus({
    required this.status,
    this.service,
    this.version,
    this.checkedAt,
    this.serverTime,
    this.uptimeSeconds,
    this.checks = const {},
    this.error,
  });

  bool get isHealthy => status == 'ok';

  factory SystemStatus.fromJson(
    Map<String, dynamic> json, {
    DateTime? checkedAt,
  }) {
    return SystemStatus(
      status: (json['status'] as String?) ?? 'unknown',
      service: json['service'] as String?,
      version: json['version'] as String?,
      checkedAt: checkedAt ?? DateTime.now().toUtc(),
      serverTime: DateTime.tryParse((json['time'] as String?) ?? ''),
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt(),
      checks: _stringMap(json['checks']),
      error: json['error'] as String?,
    );
  }

  factory SystemStatus.unreachable({
    String error = 'Backend health endpoint is unreachable',
  }) {
    return SystemStatus(status: 'unreachable', error: error);
  }

  factory SystemStatus.degraded({
    required String reason,
    Map<String, String> checks = const {},
  }) {
    return SystemStatus(status: 'degraded', error: reason, checks: checks);
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, check) => MapEntry(key.toString(), check.toString()),
    );
  }
}
