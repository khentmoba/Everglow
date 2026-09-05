import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/wiki/data/models/wiki_page.dart';

WikiShelf _shelf() => WikiShelf(
      id: 's1',
      title: 'Our Story',
      description: 'How we met',
      createdBy: 'khent',
      createdAt: DateTime.utc(2026, 9, 1),
      order: 2,
    );

WikiPage _page() => WikiPage(
      id: 'p1',
      bookId: 'b1',
      title: 'First Date',
      markdown: 'Coffee and a long walk by the river.',
      author: 'clair',
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 2),
      tags: const ['dates'],
      wordCount: 8,
    );

void main() {
  group('WikiShelf', () {
    test('toFirestore keeps order and icon', () {
      final map = _shelf().toFirestore();

      expect(map['title'], 'Our Story');
      expect(map['order'], 2);
      expect(map['icon'], isNotEmpty);
    });

    test('icon defaults to the books emoji', () {
      final shelf = WikiShelf(
        id: 's2',
        title: 'T',
        createdBy: 'clair',
        createdAt: DateTime.utc(2026, 9, 1),
      );

      expect(shelf.icon, isNotEmpty);
      expect(shelf.description, isEmpty);
      expect(shelf.order, 0);
    });
  });

  group('WikiBook', () {
    test('toFirestore links the book to its shelf', () {
      final map = WikiBook(
        id: 'b1',
        shelfId: 's1',
        title: 'Dates',
        createdBy: 'khent',
        createdAt: DateTime.utc(2026, 9, 1),
        order: 1,
      ).toFirestore();

      expect(map['shelfId'], 's1');
      expect(map['title'], 'Dates');
      expect(map['coverColor'], isNotEmpty);
      expect(map['order'], 1);
    });
  });

  group('WikiPage', () {
    test('toFirestore builds a search key from title and text', () {
      final map = _page().toFirestore();

      expect(map['bookId'], 'b1');
      expect(map['wordCount'], 8);
      expect(map['isPinned'], isFalse);
      expect(map['searchKey'], contains('first date'));
      expect(map['searchKey'], contains('coffee'));
    });

    test('defaults are an empty untagged draft', () {
      final page = WikiPage(
        id: 'p2',
        bookId: 'b1',
        title: 'T',
        author: 'khent',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );

      expect(page.markdown, isEmpty);
      expect(page.tags, isEmpty);
      expect(page.wordCount, 0);
      expect(page.isPinned, isFalse);
    });
  });
}
