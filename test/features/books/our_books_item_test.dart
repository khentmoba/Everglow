import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/books/data/models/our_books_item.dart';

void main() {
  group('OurBooksItem', () {
    test('fromFirestore reads every field', () {
      final added = DateTime.utc(2026, 9, 10);
      final item = OurBooksItem.fromFirestore({
        'workKey': '/works/OL1W',
        'editionKey': '/books/OL1M',
        'iaId': 'somebook',
        'title': 'The Little Prince',
        'author': 'Antoine de Saint-Exupéry',
        'coverUrl': 'https://covers/u.jpg',
        'year': '1943',
        'subjects': ['Fable'],
        'addedBy': 'khentsgdz',
        'addedAt': Timestamp.fromDate(added),
      }, 'doc1');

      expect(item.id, 'doc1');
      expect(item.title, 'The Little Prince');
      expect(item.subjects, ['Fable']);
      expect(item.addedAt.millisecondsSinceEpoch,
          added.millisecondsSinceEpoch);
      expect(item.status, 'to-read');
      expect(item.readSourceLabel, 'Internet Archive');
    });

    test('status tracks who finished the book', () {
      final base = OurBooksItem.fromFirestore({
        'workKey': '/works/OL1W',
        'title': 'Dune',
        'addedBy': 'clairjassen',
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
      }, 'doc2');

      expect(base.status, 'to-read');
      expect(
        base.copyWith(khentReadAt: DateTime.utc(2026, 9, 11)).status,
        'read-khent',
      );
      expect(
        base.copyWith(clairReadAt: DateTime.utc(2026, 9, 12)).status,
        'read-clair',
      );
      expect(
        base
            .copyWith(
              khentReadAt: DateTime.utc(2026, 9, 11),
              clairReadAt: DateTime.utc(2026, 9, 12),
            )
            .status,
        'read-both',
      );
    });

    test('fromFirestore never crashes on odd field types', () {
      final item = OurBooksItem.fromFirestore({
        'workKey': 1,
        'editionKey': true,
        'iaId': ['x'],
        'title': 42,
        'author': 7,
        'coverUrl': 9,
        'year': 1943,
        'subjects': 'Fable',
        'addedBy': 0,
        'addedAt': 'not-a-date',
        'khentReadAt': 'never',
        'clairReadAt': {'at': 'now'},
      }, 'doc3');

      expect(item.workKey, isEmpty);
      expect(item.title, isEmpty);
      expect(item.author, isEmpty);
      expect(item.coverUrl, isEmpty);
      expect(item.year, isEmpty);
      expect(item.subjects, isEmpty);
      expect(item.addedBy, isEmpty);
      expect(item.addedAt, isA<DateTime>());
      expect(item.khentReadAt, isNull);
      expect(item.clairReadAt, isNull);
      expect(item.status, 'to-read');
    });
  });
}
