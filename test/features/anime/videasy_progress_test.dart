import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/anime/presentation/widgets/animex/animex_videasy_progress.dart';

void main() {
  group('parseVideasyProgress', () {
    test('parses a progress tick from the live origin', () {
      final p = parseVideasyProgress(
        'https://player.videasy.to',
        '{"id":123,"type":"tv","progress":12,"timestamp":95.5,"duration":1400,"season":1,"episode":3}',
      );
      expect(p?.positionSeconds, 95.5);
      expect(p?.durationSeconds, 1400);
      expect(p?.episode, 3);
    });

    test('accepts the legacy .net origin too', () {
      final p = parseVideasyProgress(
        'https://player.videasy.net',
        '{"timestamp":10,"duration":1400}',
      );
      expect(p?.positionSeconds, 10);
      expect(p?.episode, isNull);
    });

    test('rejects foreign origins', () {
      expect(
        parseVideasyProgress(
          'https://evil.example.com',
          '{"timestamp":10,"duration":1400}',
        ),
        isNull,
      );
    });

    test('rejects malformed payloads, never throws', () {
      const origin = 'https://player.videasy.to';
      expect(parseVideasyProgress(origin, ''), isNull);
      expect(parseVideasyProgress(origin, 'not json'), isNull);
      expect(parseVideasyProgress(origin, '[]'), isNull);
      expect(parseVideasyProgress(origin, '{}'), isNull);
      expect(
        parseVideasyProgress(origin, '{"timestamp":-5,"duration":100}'),
        isNull,
      );
      expect(
        parseVideasyProgress(origin, '{"timestamp":5,"duration":0}'),
        isNull,
      );
      expect(
        parseVideasyProgress(origin, '{"timestamp":"soon","duration":100}'),
        isNull,
      );
    });
  });
}
