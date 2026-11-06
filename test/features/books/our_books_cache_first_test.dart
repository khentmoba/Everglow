// The books rail must paint the shelf already on this device before Firestore
// answers. Same contract as the journal preview: a WebChannel round trip for
// books the phone already has is the wait Clair reported, so the cached frame
// has to arrive first and the live snapshot replaces it afterwards.
//
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/books/data/services/our_books_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/firestore_test_fakes.dart';

/// A collection whose snapshot stream never emits, standing in for a cold
/// WebChannel on a weak signal.
class _SilentCollection extends TestCollection {
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> cachedBook({
    String id = 'book-1',
    String title = 'The Little Prince',
    String addedBy = 'clairjassen',
  }) => {
    'id': id,
    'workKey': 'OL123W',
    'editionKey': 'OL456M',
    'iaId': '',
    'title': title,
    'author': 'Antoine de Saint-Exupéry',
    'coverUrl': '',
    'year': '1943',
    'subjects': const ['fable'],
    'addedBy': addedBy,
    'addedAt': '2026-02-01T10:00:00.000Z',
    'khentReadAt': null,
    'clairReadAt': null,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_our_books': jsonEncode([cachedBook()]),
    });
  });

  group('our books cache-first', () {
    test('getCachedOurBooks reads the shelf written by a previous visit',
        () async {
      final service = OurBooksService(
        firestore: TestFirestore(_SilentCollection()),
      );

      final cached = await service.getCachedOurBooks();

      expect(cached, hasLength(1));
      expect(cached.single.title, 'The Little Prince');
      expect(cached.single.addedBy, 'clairjassen');
      expect(cached.single.addedAt, DateTime.utc(2026, 2, 1, 10));
    });

    test('getOurBooksStream paints the cache while the server stays silent',
        () async {
      final service = OurBooksService(
        firestore: TestFirestore(_SilentCollection()),
      );

      // .first must complete from cache alone: the live stream never emits,
      // so anything that reached Firestore here would hang until the guard.
      final first = await service.getOurBooksStream().first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError(
          'getOurBooksStream waited on Firestore instead of painting the cache',
        ),
      );

      expect(first, hasLength(1));
      expect(first.single.title, 'The Little Prince');
    });

    test('the per-partner rail paints only that partner, from cache', () async {
      SharedPreferences.setMockInitialValues({
        'cached_our_books': jsonEncode([
          cachedBook(id: 'a', title: 'Hers', addedBy: 'clairjassen'),
          cachedBook(id: 'b', title: 'His', addedBy: 'khentsgdz'),
        ]),
      });
      final service = OurBooksService(
        firestore: TestFirestore(_SilentCollection()),
      );

      final hers = await service
          .getOurBooksByAdderPreviewStream('clairjassen')
          .first
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError(
              'partner rail waited on Firestore instead of painting the cache',
            ),
          );

      expect(hers, hasLength(1));
      expect(hers.single.title, 'Hers');
    });

    test('an empty cache leaves the stream to the live query', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OurBooksService(
        firestore: TestFirestore(_SilentCollection()),
      );

      expect(await service.getCachedOurBooks(), isEmpty);
    });
  });
}
