import 'package:everglow/features/ai/domain/mochi_grounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grounding = MochiGrounding();

  group('MochiGrounding.extractTitles', () {
    test('finds quoted and bold titles, deduped', () {
      final titles = grounding.extractTitles(
        'Try "Dune" or **Interstellar** tonight. "Dune" is epic!',
      );
      expect(titles, ['Dune', 'Interstellar']);
    });

    test('ignores single chars and plain prose', () {
      expect(grounding.extractTitles('a "x" y'), isEmpty);
      expect(grounding.extractTitles('just a warm hello'), isEmpty);
    });
  });

  group('MochiGrounding.titlesMatch', () {
    test('matches either direction, case-insensitively', () {
      expect(grounding.titlesMatch('Dune: Part Two', 'dune'), isTrue);
      expect(grounding.titlesMatch('Dune', 'Dune: Part Two'), isTrue);
      expect(grounding.titlesMatch('Dune', 'Interstellar'), isFalse);
      expect(grounding.titlesMatch('', 'Dune'), isFalse);
    });
  });

  group('MochiGrounding.findUnknownTitles', () {
    test('passes replies grounded in known titles', () {
      final unknown = grounding.findUnknownTitles(
        'Watch "Dune" then **Interstellar** — both classics.',
        ['Dune: Part Two', 'Interstellar (2014)'],
      );
      expect(unknown, isEmpty);
    });

    test('flags invented titles for self-healing', () {
      final unknown = grounding.findUnknownTitles(
        'Watch "Dune" and "Galactic Hamsters 9" tonight.',
        ['Dune', 'Interstellar'],
      );
      expect(unknown, ['Galactic Hamsters 9']);
      expect(
        grounding.hasHallucinatedTitle(
          'Watch "Dune" and "Galactic Hamsters 9" tonight.',
          ['Dune', 'Interstellar'],
        ),
        isTrue,
      );
    });

    test('replies without titles never trigger healing', () {
      expect(
        grounding.hasHallucinatedTitle(
          'Hope you two have a cozy night!',
          ['Dune'],
        ),
        isFalse,
      );
    });
  });
}
