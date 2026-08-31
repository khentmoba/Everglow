import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/models/our_books_item.dart';

void main() {
  group('BookItem', () {
    test('isRead covers every read status variant', () {
      BookItem withStatus(String status) => BookItem(
            id: 'doc1',
            workKey: '/works/OL45804W',
            title: 'T',
            status: status,
            addedAt: DateTime.utc(2026, 1, 1),
          );

      for (final s in ['read', 'read-khent', 'read-clair', 'read-both', 'read-self']) {
        expect(withStatus(s).isRead, isTrue, reason: 'status "$s" should be read');
      }
      expect(withStatus('to-read').isRead, isFalse);
    });

    test('readDisplay maps statuses to labels', () {
      BookItem display(String status) => BookItem(
            id: 'doc1',
            workKey: '/works/OL45804W',
            title: 'T',
            status: status,
            addedAt: DateTime.utc(2026, 1, 1),
          );

      expect(display('read-khent').readDisplay, 'Read by Khent');
      expect(display('read-clair').readDisplay, 'Read by Clair');
      expect(display('read-both').readDisplay, 'Read by Both');
      expect(display('read').readDisplay, 'Read by Both');
      expect(display('read-self').readDisplay, 'Read');
      expect(display('to-read').readDisplay, 'To Read');
    });

    test('cover helpers derive Open Library CDN URLs', () {
      expect(BookItem.coverFromCoverId(12345), 'https://covers.openlibrary.org/b/id/12345-L.jpg');
      expect(BookItem.coverFromCoverId(12345, size: 'M'), 'https://covers.openlibrary.org/b/id/12345-M.jpg');
      expect(BookItem.coverFromCoverId(null), '');
      expect(BookItem.coverFromCoverId(0), '');
      expect(BookItem.coverFromOlid('OL45804W'), 'https://covers.openlibrary.org/b/olid/OL45804W-L.jpg');
      expect(BookItem.coverFromOlid(''), '');
    });

    test('deriveReadSourceUrl routes Gutenberg, IA, and Open Library', () {
      expect(
        BookItem.deriveReadSourceUrl(iaId: 'pg1234', workKey: '/works/OL1W'),
        'https://www.gutenberg.org/cache/epub/1234/pg1234.txt',
      );
      expect(
        BookItem.deriveReadSourceUrl(iaId: 'adventureoftoms00twai', workKey: '/works/OL1W'),
        'https://archive.org/details/adventureoftoms00twai',
      );
      expect(
        BookItem.deriveReadSourceUrl(iaId: '', workKey: '/works/OL45804W'),
        'https://openlibrary.org/works/OL45804W',
      );
      expect(BookItem.deriveReadSourceUrl(iaId: '', workKey: ''), '');
    });

    test('deriveReadSourceLabel prefers Gutenberg then IA then OL', () {
      expect(BookItem.deriveReadSourceLabel(iaId: 'pg1234'), 'Project Gutenberg');
      expect(BookItem.deriveReadSourceLabel(iaId: 'ia1234'), 'Internet Archive');
      expect(BookItem.deriveReadSourceLabel(iaId: ''), 'Open Library');
    });

    test('toFirestore/fromFirestore round-trips every persisted field', () {
      final addedAt = DateTime.utc(2026, 8, 14, 12, 30);
      final book = BookItem(
        id: 'doc1',
        workKey: '/works/OL45804W',
        editionKey: '/books/OL1M',
        iaId: 'pg1234',
        title: 'The Adventures of Tom Sawyer',
        author: 'Mark Twain',
        coverUrl: 'https://covers.openlibrary.org/b/id/12345-L.jpg',
        year: '1876',
        pageCount: 274,
        subjects: const ['adventure', 'childhood'],
        status: 'read-both',
        userName: 'khentsgdz',
        addedAt: addedAt,
        readSourceUrl: 'https://www.gutenberg.org/cache/epub/1234/pg1234.txt',
        readSourceLabel: 'Project Gutenberg',
      );

      final data = book.toFirestore();
      expect(data['addedAt'], isA<Timestamp>());

      final restored = BookItem.fromFirestore(data, 'doc1');
      expect(restored.workKey, book.workKey);
      expect(restored.editionKey, book.editionKey);
      expect(restored.iaId, book.iaId);
      expect(restored.title, book.title);
      expect(restored.author, book.author);
      expect(restored.coverUrl, book.coverUrl);
      expect(restored.year, book.year);
      expect(restored.pageCount, book.pageCount);
      expect(restored.subjects, book.subjects);
      expect(restored.status, book.status);
      expect(restored.userName, book.userName);
      expect(restored.addedAt.millisecondsSinceEpoch,
          addedAt.millisecondsSinceEpoch);
      expect(restored.readSourceUrl, book.readSourceUrl);
    });

    test('fromFirestore re-derives read source for legacy documents', () {
      final restored = BookItem.fromFirestore({
        'workKey': '/works/OL45804W',
        'title': 'Tom Sawyer',
        'iaId': 'pg74',
        'status': 'to-read',
        // No readSourceUrl — legacy document.
      }, 'doc1');

      expect(restored.readSourceUrl,
          'https://www.gutenberg.org/cache/epub/74/pg74.txt');
      expect(restored.readSourceLabel, 'Project Gutenberg');
    });
  });

  group('OurBooksItem', () {
    OurBooksItem item({DateTime? khentReadAt, DateTime? clairReadAt}) =>
        OurBooksItem(
          id: 'doc1',
          workKey: '/works/OL45804W',
          iaId: 'pg74',
          title: 'The Adventures of Tom Sawyer',
          author: 'Mark Twain',
          addedBy: 'khentsgdz',
          addedAt: DateTime.utc(2026, 1, 1),
          khentReadAt: khentReadAt,
          clairReadAt: clairReadAt,
        );

    test('status reflects which partners have read the book', () {
      expect(item().status, 'to-read');
      expect(
          item(khentReadAt: DateTime.utc(2026, 2, 1)).status, 'read-khent');
      expect(
          item(clairReadAt: DateTime.utc(2026, 2, 1)).status, 'read-clair');
      expect(
        item(
          khentReadAt: DateTime.utc(2026, 2, 1),
          clairReadAt: DateTime.utc(2026, 2, 2),
        ).status,
        'read-both',
      );
    });

    test('statusLabel maps statuses for display', () {
      expect(item().statusLabel, 'To Read Together');
      expect(item(khentReadAt: DateTime.utc(2026, 2, 1)).statusLabel,
          'Read by Khent');
      expect(item(clairReadAt: DateTime.utc(2026, 2, 1)).statusLabel,
          'Read by Clair');
      expect(
        item(
          khentReadAt: DateTime.utc(2026, 2, 1),
          clairReadAt: DateTime.utc(2026, 2, 2),
        ).statusLabel,
        'Read by Both',
      );
    });

    test('readSourceLabel derives from iaId/workKey', () {
      expect(item().readSourceLabel, 'Internet Archive');
      expect(
        OurBooksItem(
          id: 'd',
          workKey: '/works/OL1W',
          iaId: '',
          title: 'T',
          addedBy: 'khentsgdz',
          addedAt: DateTime.utc(2026, 1, 1),
        ).readSourceLabel,
        'Open Library',
      );
    });

    test('toBookItem carries fields through with couple status', () {
      final source = item(
        khentReadAt: DateTime.utc(2026, 2, 1),
        clairReadAt: DateTime.utc(2026, 2, 2),
      );
      final book = source.toBookItem();

      expect(book.id, source.id);
      expect(book.workKey, source.workKey);
      expect(book.iaId, source.iaId);
      expect(book.title, source.title);
      expect(book.userName, source.addedBy);
      expect(book.status, 'read-both');
    });

    test('toFirestore/fromFirestore round-trips nullable read stamps', () {
      final source = item(
        khentReadAt: DateTime.utc(2026, 2, 1, 8, 0),
      );
      final restored = OurBooksItem.fromFirestore(
        source.toFirestore(),
        'doc1',
      );

      expect(restored.khentReadAt, isNotNull);
      expect(restored.khentReadAt!.millisecondsSinceEpoch,
          source.khentReadAt!.millisecondsSinceEpoch);
      expect(restored.clairReadAt, isNull);
    });

    test('copyWith clears read stamps with explicit clear flags', () {
      final source = item(
        khentReadAt: DateTime.utc(2026, 2, 1),
        clairReadAt: DateTime.utc(2026, 2, 2),
      );

      final clearedKhent = source.copyWith(clearKhentRead: true);
      expect(clearedKhent.khentReadAt, isNull);
      expect(clearedKhent.clairReadAt, source.clairReadAt);

      final clearedClair = source.copyWith(clearClairRead: true);
      expect(clearedClair.khentReadAt, source.khentReadAt);
      expect(clearedClair.clairReadAt, isNull);
    });
  });
}
