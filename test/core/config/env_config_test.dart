import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/config/env_config.dart';

void main() {
  test('FCM VAPID key keeps its public fallback for web push registration', () {
    expect(EnvConfig.fcmVapidKey, isNotEmpty);
    expect(EnvConfig.fcmVapidKey, startsWith('BL2l'));
  });
}
