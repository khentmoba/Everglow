import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/network/network_quality_service.dart';

void main() {
  setUp(() {
    NetworkQualityService.debugReset();
  });

  tearDown(() {
    NetworkQualityService.debugReset();
  });

  group('NetworkQualityService', () {
    test('defaults to fast network quality', () {
      final service = NetworkQualityService.instance;
      expect(service.quality, NetworkQuality.fast);
      expect(service.isSlowConnection, isFalse);
      expect(service.isSaveData, isFalse);
    });

    test('isSlowConnection is true when quality is slow', () {
      final service = NetworkQualityService.instance;
      NetworkQualityService.debugOverrideQuality = NetworkQuality.slow;

      expect(service.quality, NetworkQuality.slow);
      expect(service.isSlowConnection, isTrue);
    });

    test('isSlowConnection is false when quality is moderate or fast', () {
      final service = NetworkQualityService.instance;

      NetworkQualityService.debugOverrideQuality = NetworkQuality.moderate;
      expect(service.isSlowConnection, isFalse);

      NetworkQualityService.debugOverrideQuality = NetworkQuality.fast;
      expect(service.isSlowConnection, isFalse);
    });

    test('isSaveData reflects debug override', () {
      final service = NetworkQualityService.instance;

      NetworkQualityService.debugOverrideSaveData = true;
      expect(service.isSaveData, isTrue);

      NetworkQualityService.debugOverrideSaveData = false;
      expect(service.isSaveData, isFalse);
    });
  });
}
