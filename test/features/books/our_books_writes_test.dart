// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/our_books_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/firestore_test_fakes.dart' as query;
import '../../support/transaction_test_fakes.dart' as tx;

class _BooksDb extends tx.TransactionFirestore {
  List<Map<String, dynamic>> legacy = [];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _BooksCollection(this);
}

class _BooksCollection extends tx.TransactionCollection {
  _BooksCollection(_BooksDb super.db);
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => query.TestCollection(entries: (db as _BooksDb).legacy);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _BookDocument(db, path!);
}

class _BookDocument extends tx.TransactionDocument {
  _BookDocument(super.db, this.id);
  @override
  final String id;
}

void main() {
  BookItem book() => BookItem(
    id: 'demo',
    workKey: '/works/OL123W',
    title: 'Demo book',
    status: 'to-read',
    addedAt: DateTime(2026),
  );
  test('client and server derive the same book id', () {
    expect(
      OurBooksService.bookDocumentId('/works/OL123W'),
      '48da23763e038af20b0d295f141fce2b65c71e2d21180caf005f0e5c3216da72',
    );
  });
  test(
    'simultaneous book saves create one record without overwriting reading flags',
    () async {
      final db = _BooksDb();
      final service = OurBooksService(firestore: db);
      final saved = await Future.wait([
        service.addToOurBooks(book(), 'khentsgdz'),
        service.addToOurBooks(book(), 'clairjassen'),
      ]);
      expect(saved.every((entry) => entry != null), true);
      expect(saved[0]!.id, saved[1]!.id);
      expect(db.writeAttempts, 1);
      final readAt = Timestamp.fromDate(DateTime(2026, 10));
      db.data!['clairReadAt'] = readAt;
      await service.addToOurBooks(book(), 'clairjassen');
      expect(db.data!['clairReadAt'], readAt);
      expect(db.writeAttempts, 1);
    },
  );
  test(
    'archive and Gutenberg books without work keys still save with stable ids',
    () async {
      final db = _BooksDb();
      final item = BookItem(
        id: '',
        workKey: '',
        iaId: 'pg123',
        title: 'Demo archive book',
        status: 'to-read',
        addedAt: DateTime(2026),
      );
      final saved = await OurBooksService(
        firestore: db,
      ).addToOurBooks(item, 'clairjassen');
      expect(saved, isNotNull);
      expect(saved!.workKey, 'ia:pg123');
      expect(saved.iaId, 'pg123');
      expect(saved.id, OurBooksService.bookDocumentId('ia:pg123'));
    },
  );

  test('legacy random-id book records are reused', () async {
    final db = _BooksDb()
      ..legacy = [
        {
          'workKey': '/works/OL123W',
          'title': 'Demo book',
          'addedBy': 'khentsgdz',
          'addedAt': Timestamp.fromDate(DateTime(2026)),
        },
      ];
    final saved = await OurBooksService(
      firestore: db,
    ).addToOurBooks(book(), 'clairjassen');
    expect(saved!.id, '0');
    expect(db.writeAttempts, 0);
  });
}
