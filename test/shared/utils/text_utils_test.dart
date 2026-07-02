import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/shared/utils/text_utils.dart';

void main() {
  group('stripMarkdown', () {
    test('removes bold markers', () {
      expect(stripMarkdown('**bold** text'), 'bold text');
      expect(stripMarkdown('**bold**'), 'bold');
    });

    test('removes italic markers', () {
      expect(stripMarkdown('*italic* text'), 'italic text');
      expect(stripMarkdown('_italic_ text'), 'italic text');
    });

    test('removes inline code backticks', () {
      expect(stripMarkdown('`code` here'), 'code here');
    });

    test('removes strikethrough', () {
      expect(stripMarkdown('~~strike~~ through'), 'strike through');
    });

    test('removes heading markers', () {
      expect(stripMarkdown('### Heading 3'), 'Heading 3');
      expect(stripMarkdown('## Heading 2'), 'Heading 2');
      expect(stripMarkdown('# Heading 1'), 'Heading 1');
    });

    test('handles mixed formatting', () {
      expect(
        stripMarkdown('**bold** and *italic* and `code`'),
        'bold and italic and code',
      );
    });

    test('handles empty string', () {
      expect(stripMarkdown(''), '');
    });

    test('handles string with no markdown', () {
      expect(stripMarkdown('plain text'), 'plain text');
    });
  });

  group('extractTitles', () {
    test('parses numbered list from AI response', () {
      final result = extractTitles(
        '1. The Shawshank Redemption (1994)\n'
        '2. The Godfather (1972)\n'
        '3. Pulp Fiction (1994)',
      );
      expect(result, [
        'The Shawshank Redemption',
        'The Godfather',
        'Pulp Fiction',
      ]);
    });

    test('parses bullet list with markdown bold numbers', () {
      final result = extractTitles(
        '**1.** Inception (2010)\n'
        '- Interstellar (2014)\n'
        '* The Matrix (1999)',
      );
      expect(result, ['Inception', 'Interstellar', 'The Matrix']);
    });

    test('handles intro text before numbered list', () {
      final result = extractTitles(
        'here are some recommendations:\n'
        '1. Dune (2021)\n',
      );
      // Intro line starts with lowercase so it's filtered out
      expect(result, ['Dune']);
    });

    test('returns empty list for empty input', () {
      expect(extractTitles(''), []);
    });

    test('returns empty list for text with no titles', () {
      expect(extractTitles('I have no recommendations right now.'), []);
    });

    test('handles titles with years in parentheses', () {
      final result = extractTitles(
        '1. The Batman (2022) - great noir style',
      );
      expect(result, ['The Batman']);
    });

    test('handles titles without years', () {
      final result = extractTitles(
        '1. Everything Everywhere All At Once',
      );
      expect(result, ['Everything Everywhere All At Once']);
    });
  });
}
