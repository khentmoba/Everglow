import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/journal/data/models/journal_entry.dart';

JournalEntry _entry() => JournalEntry(
      id: 'j1',
      title: 'Beach Day',
      content: 'We watched the sunset and ate ice cream.',
      author: 'Khent',
      createdAt: DateTime.utc(2026, 9, 5, 18, 30),
      updatedAt: DateTime.utc(2026, 9, 5, 19, 0),
      category: JournalCategory.memory,
      mood: JournalMood.loved,
      tags: const ['beach', 'sunset'],
      wordCount: 8,
    );

void main() {
  group('JournalEntry', () {
    test('toFirestore lowercases the author and stamps month-day', () {
      final map = _entry().toFirestore();

      expect(map['author'], 'khent');
      expect(map['category'], 'memory');
      expect(map['mood'], 'loved');
      expect(map['monthDay'], '09-05');
      expect(map['searchKey'], contains('beach day'));
      expect(map['searchKey'], contains('sunset'));
    });

    test('toFirestore omits null mood and cover color', () {
      final map = JournalEntry(
        id: 'j2',
        title: 'T',
        content: 'C',
        author: 'clair',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ).toFirestore();

      expect(map.containsKey('mood'), isFalse);
      expect(map.containsKey('coverColor'), isFalse);
    });

    test('copyWith clears mood and cover color only when asked', () {
      final base = _entry().copyWith(coverColor: '#ff0000');

      expect(base.copyWith().mood, JournalMood.loved);
      expect(base.copyWith().coverColor, '#ff0000');
      expect(base.copyWith(clearMood: true).mood, isNull);
      expect(base.copyWith(clearCoverColor: true).coverColor, isNull);
    });

    test('isLong flags entries over 200 words', () {
      expect(_entry().isLong, isFalse);
      expect(_entry().copyWith(wordCount: 201).isLong, isTrue);
    });

    test('preview truncates long content', () {
      final long = _entry().copyWith(content: List.filled(200, 'a').join());

      expect(long.preview.length, 121);
      expect(_entry().preview, _entry().content);
    });

    test('every category and mood has a label and emoji', () {
      for (final c in JournalCategory.values) {
        expect(c.displayName, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
      for (final m in JournalMood.values) {
        expect(m.key, isNotEmpty);
        expect(m.emoji, isNotEmpty);
      }
    });
  });
}
