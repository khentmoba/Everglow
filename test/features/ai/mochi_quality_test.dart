import 'package:everglow/features/ai/domain/mochi_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const quality = MochiQuality();
  const selector = ContextSelector();

  group('MochiQuality.shouldAutoThink', () {
    test('short casual messages stay on the fast path', () {
      expect(quality.shouldAutoThink('hi mochi'), isFalse);
      expect(quality.shouldAutoThink('i love you'), isFalse);
    });

    test('planning and relationship questions get deep thinking', () {
      expect(quality.shouldAutoThink('plan our anniversary date'), isTrue);
      expect(quality.shouldAutoThink('why are we like this'), isTrue);
    });

    test('long multi-part messages get deep thinking', () {
      expect(
        quality.shouldAutoThink(
          'Can you compare our moods this week and suggest something '
          'we can do together on Saturday that fits how we are feeling?',
        ),
        isTrue,
      );
    });
  });

  group('ContextSelector', () {
    test('keeps only relevant blocks plus the proactive digest', () {
      final selected = selector.select({
        'proactive': 'Birthday in 5 days',
        'movies': 'Watchlist: Interstellar, Dune',
        'books': 'Our Books: The Midnight Library',
        'music': 'Recently played: Ethel Cain',
        'mood': 'Clair logged happy today',
        'chat': 'Recent chat messages',
        'garden': 'Garden has 4 flowers',
      }, 'what should we watch tonight');

      expect(selected.first.key, 'proactive');
      expect(selected.any((e) => e.key == 'movies'), isTrue);
      expect(selected.any((e) => e.key == 'music'), isFalse);
      expect(selected.length, lessThanOrEqualTo(6));
    });

    test('empty query returns first blocks', () {
      final selected = selector.select({
        'a': 'alpha',
        'b': 'beta',
      }, '');
      expect(selected.map((e) => e.key), ['a', 'b']);
    });
  });
}
