import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/starlight_jar/domain/models/star_note.dart';

StarNote _note() => StarNote(
      id: 's1',
      content: 'Thank you for today',
      author: 'clair',
      timestamp: DateTime.utc(2026, 9, 5),
      category: 'love',
      tags: const ['date'],
    );

void main() {
  group('StarNote', () {
    test('toMap keeps content, author, category and tags', () {
      final map = _note().toMap();

      expect(map['content'], 'Thank you for today');
      expect(map['author'], 'clair');
      expect(map['category'], 'love');
      expect(map['tags'], ['date']);
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('defaults are a gratitude note with no tags', () {
      final note = StarNote(
        id: 's2',
        content: 'Hi',
        author: 'khent',
        timestamp: DateTime.utc(2026, 9, 5),
      );

      expect(note.category, 'gratitude');
      expect(note.tags, isEmpty);
    });

    test('every category has an emoji and a label', () {
      expect(starCategoryInfo.keys.toSet(), starCategories.toSet());
      for (final c in starCategories) {
        final info = starCategoryInfo[c]!;
        expect(info.$1, isNotEmpty);
        expect(info.$2, isNotEmpty);
      }
    });
  });
}

