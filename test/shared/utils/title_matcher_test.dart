import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/utils/title_matcher.dart';

void main() {
  group('TitleMatcher.titlesMatch', () {
    test('matches identical titles ignoring case and punctuation', () {
      expect(TitleMatcher.titlesMatch('Dune', 'Dune'), isTrue);
      expect(
        TitleMatcher.titlesMatch('Dune: Part Two', 'dune part two'),
        isTrue,
      );
      expect(TitleMatcher.titlesMatch('Spider-Man', 'spider man'), isTrue);
    });

    test('matches when one title contains the other (min length 4)', () {
      expect(TitleMatcher.titlesMatch('Dune: Part Two', 'dune'), isTrue);
      expect(TitleMatcher.titlesMatch('Dune', 'Dune: Part Two'), isTrue);
    });

    test('rejects short-substring false positives', () {
      // "split".contains("it") is true at the string level, but "It" and
      // "Split" are different films — short titles only match exactly.
      expect(TitleMatcher.titlesMatch('It', 'Split'), isFalse);
      expect(TitleMatcher.titlesMatch('Up', 'Up in the Air'), isFalse);
      expect(TitleMatcher.titlesMatch('Us', 'Sus'), isFalse);
    });

    test('strips generic media suffixes before matching', () {
      // Live regression: stored "Yellow Jacket Television" and
      // "Yellow Jacket Televison" (misspelling) never matched TMDB's
      // "Yellowjackets", so the poster stayed blank forever.
      expect(
        TitleMatcher.titlesMatch('Yellow Jacket Television', 'Yellowjackets'),
        isTrue,
      );
      expect(
        TitleMatcher.titlesMatch('Yellow Jacket Televison', 'Yellowjackets'),
        isTrue,
      );
      expect(TitleMatcher.titlesMatch('Dune Movie', 'Dune'), isTrue);
      expect(TitleMatcher.titlesMatch('The Office TV', 'The Office'), isTrue);
      expect(
        TitleMatcher.titlesMatch('Attack on Titan Anime', 'Attack on Titan'),
        isTrue,
      );
      expect(
        TitleMatcher.titlesMatch('Stranger Things Season', 'Stranger Things'),
        isTrue,
      );
    });

    test('matches compound words spacelessly', () {
      expect(
        TitleMatcher.titlesMatch('Yellow Jacket', 'Yellowjackets'),
        isTrue,
      );
      expect(TitleMatcher.titlesMatch('Spider Man', 'Spiderman'), isTrue);
    });

    test('rejects genuinely different titles', () {
      expect(TitleMatcher.titlesMatch('Dune', 'Interstellar'), isFalse);
      expect(TitleMatcher.titlesMatch('', 'Dune'), isFalse);
      expect(TitleMatcher.titlesMatch('Dune', ''), isFalse);
    });
  });

  group('TitleMatcher.titlesLooselyMatch', () {
    test('matches long shared substrings', () {
      expect(
        TitleMatcher.titlesLooselyMatch(
          'Yellow Jacket Television',
          'Yellowjackets',
        ),
        isTrue,
      );
    });

    test('rejects short titles and unrelated pairs', () {
      expect(TitleMatcher.titlesLooselyMatch('It', 'Split'), isFalse);
      expect(TitleMatcher.titlesLooselyMatch('Dune', 'Interstellar'), isFalse);
      expect(TitleMatcher.titlesLooselyMatch('Up', 'Us'), isFalse);
    });
  });

  group('TitleMatcher.stripGenerics', () {
    test('removes media suffixes and leading articles', () {
      expect(
        TitleMatcher.stripGenerics('Yellow Jacket Televison'),
        'yellow jacket',
      );
      expect(
        TitleMatcher.stripGenerics('Yellow Jacket Television'),
        'yellow jacket',
      );
      expect(TitleMatcher.stripGenerics('The Office TV'), 'office');
      expect(TitleMatcher.stripGenerics('Dune Movie'), 'dune');
      expect(
        TitleMatcher.stripGenerics('Stranger Things Series'),
        'stranger things',
      );
    });
  });

  group('TitleMatcher.searchCandidates', () {
    test(
      'generates ranked candidates for titles with suffixes and compounds',
      () {
        final candidates = TitleMatcher.searchCandidates(
          'Yellow Jacket Televison',
        );
        expect(candidates, contains('Yellow Jacket Televison'));
        expect(candidates, contains('yellow jacket'));
        expect(candidates, contains('yellowjackets'));
        expect(candidates, contains('yellowjacket'));
      },
    );

    test('generates candidates for titles with leading articles', () {
      final candidates = TitleMatcher.searchCandidates('The Office TV');
      expect(candidates, contains('The Office TV'));
      expect(candidates, contains('office'));
    });

    test('returns empty for empty or whitespace titles', () {
      expect(TitleMatcher.searchCandidates(''), isEmpty);
      expect(TitleMatcher.searchCandidates('   '), isEmpty);
    });
  });
}
