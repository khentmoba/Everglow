import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/models/video_source_config.dart';

void main() {
  group('VideoSourceConfig', () {
    test('fromFirestore reads every field', () {
      final config = VideoSourceConfig.fromFirestore({
        'id': 'vidfast',
        'name': 'VidFast',
        'shortName': 'VF',
        'desc': 'Fast, multiple CDN domains',
        'movieUrl': 'https://vidfast.pro/movie/',
        'tvUrl': 'https://vidfast.pro/tv/',
        'isRecommended': true,
        'sandboxSafe': true,
      });

      expect(config.id, 'vidfast');
      expect(config.name, 'VidFast');
      expect(config.shortName, 'VF');
      expect(config.desc, 'Fast, multiple CDN domains');
      expect(config.movieUrl, 'https://vidfast.pro/movie/');
      expect(config.tvUrl, 'https://vidfast.pro/tv/');
      expect(config.isRecommended, isTrue);
      expect(config.sandboxSafe, isTrue);
    });

    test('shortName falls back to name when missing', () {
      final config = VideoSourceConfig.fromFirestore({
        'name': 'VidFast',
        'movieUrl': 'https://vidfast.pro/movie/',
        'tvUrl': 'https://vidfast.pro/tv/',
      });

      expect(config.shortName, 'VidFast');
    });

    test('fromFirestore never crashes on odd field types', () {
      final config = VideoSourceConfig.fromFirestore({
        'id': 1,
        'name': ['VidFast'],
        'shortName': 7,
        'desc': true,
        'movieUrl': 42,
        'tvUrl': {'u': 'x'},
        'isRecommended': 'yes',
        'sandboxSafe': 1,
      });

      expect(config.id, isEmpty);
      expect(config.name, isEmpty);
      expect(config.shortName, isEmpty);
      expect(config.desc, isEmpty);
      expect(config.movieUrl, isEmpty);
      expect(config.tvUrl, isEmpty);
      expect(config.isRecommended, isFalse);
      expect(config.sandboxSafe, isFalse);
    });
  });
}
