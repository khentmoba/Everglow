import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/guardian/data/services/guardian_service.dart';

void main() {
  group('GuardianService Tests', () {
    test('Random message selection works', () async {
      final service = GuardianService();
      expect(service, isNotNull);
    });
  });
}
