import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/network/network_quality_service.dart';
import 'package:everglow/core/perf/device_capability.dart';
import 'package:everglow/shared/utils/tmdb_images.dart';

void main() {
  setUp(() {
    NetworkQualityService.debugReset();
    DeviceCapability.debugReset();
  });

  tearDown(() {
    NetworkQualityService.debugReset();
    DeviceCapability.debugReset();
  });

  group('TmdbImages adaptive sizing', () {
    test('uses standard w342 for cards and w500 for posters on fast network', () {
      NetworkQualityService.debugOverrideQuality = NetworkQuality.fast;
      DeviceCapability.debugOverrideLowEnd = false;

      expect(
        TmdbImages.cardFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w342/poster.jpg',
      );
      expect(
        TmdbImages.posterFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w500/poster.jpg',
      );
    });

    test('switches to w185 for cards and w342 for posters on slow network', () {
      NetworkQualityService.debugOverrideQuality = NetworkQuality.slow;

      expect(
        TmdbImages.cardFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w185/poster.jpg',
      );
      expect(
        TmdbImages.posterFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w342/poster.jpg',
      );
    });

    test('switches to w185 for cards and w342 for posters on low-end device', () {
      DeviceCapability.debugOverrideLowEnd = true;

      expect(
        TmdbImages.cardFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w185/poster.jpg',
      );
      expect(
        TmdbImages.posterFor('/poster.jpg'),
        'https://image.tmdb.org/t/p/w342/poster.jpg',
      );
    });

    test('forceFullQuality bypasses adaptive reduction when explicitly requested', () {
      NetworkQualityService.debugOverrideQuality = NetworkQuality.slow;
      DeviceCapability.debugOverrideLowEnd = true;

      expect(
        TmdbImages.cardFor('/poster.jpg', forceFullQuality: true),
        'https://image.tmdb.org/t/p/w342/poster.jpg',
      );
      expect(
        TmdbImages.posterFor('/poster.jpg', forceFullQuality: true),
        'https://image.tmdb.org/t/p/w500/poster.jpg',
      );
    });
  });
}
