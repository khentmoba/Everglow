// The journal preview must paint from the on-device cache before Firestore
// answers. Clair's report was "a note or a journal diary takes six to ten
// seconds" — that wait is a WebChannel round trip for data the phone already
// has on disk, so the contract here is: cached entries arrive first, and the
// live snapshot replaces them afterwards.
//
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
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

  final cachedEntry = JournalEntry(
    id: 'cached-1',
    title: 'The night we watched the meteor shower',
    content: 'You fell asleep before the second one.',
    author: 'clairjassen',
    createdAt: DateTime.utc(2026, 3, 14, 21, 30),
    updatedAt: DateTime.utc(2026, 3, 14, 21, 45),
    category: JournalCategory.memory,
    tags: const ['meteor', 'us'],
    isPinned: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'journal_preview_cache_v1': jsonEncode([
        {...cachedEntry.toCacheJson(), 'id': cachedEntry.id},
      ]),
    });
  });

  group('journal preview cache', () {
    test('toCacheJson round-trips through fromMap', () {
      final restored = JournalEntry.fromMap(
        cachedEntry.toCacheJson(),
        cachedEntry.id,
      );

      expect(restored.title, cachedEntry.title);
      expect(restored.content, cachedEntry.content);
      expect(restored.author, cachedEntry.author);
      expect(restored.category, cachedEntry.category);
      expect(restored.tags, cachedEntry.tags);
      expect(restored.isPinned, isTrue);
      // Timestamps survive as epoch millis, so a cached entry keeps its date.
      expect(restored.createdAt, cachedEntry.createdAt);
      expect(restored.updatedAt, cachedEntry.updatedAt);
    });

    test('loadPreviewCache reads entries written by a previous visit', () async {
      final service = JournalService(db: TestFirestore(_SilentCollection()));

      final loaded = await service.loadPreviewCache();

      expect(loaded, hasLength(1));
      expect(loaded.single.title, cachedEntry.title);
      expect(service.cachedPreview.single.id, cachedEntry.id);
    });

    test('watchPreview paints the cache while the server stays silent', () async {
      final service = JournalService(db: TestFirestore(_SilentCollection()));
      await service.loadPreviewCache();

      // .first must complete from cache alone: the live stream never emits,
      // so anything that reached Firestore here would hang until the guard.
      final first = await service.watchPreview().first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError(
          'watchPreview waited on Firestore instead of painting the cache',
        ),
      );

      expect(first, hasLength(1));
      expect(first.single.title, cachedEntry.title);
      expect(first.single.id, cachedEntry.id);
    });

    test('an empty cache leaves the stream to the live query', () async {
      SharedPreferences.setMockInitialValues({});
      final service = JournalService(db: TestFirestore(_SilentCollection()));

      final loaded = await service.loadPreviewCache();

      expect(loaded, isEmpty);
      expect(service.cachedPreview, isEmpty);
    });
  });
}
