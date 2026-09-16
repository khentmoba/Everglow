import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/data/models/katana_models.dart';

void main() {
  group('KatanaBookmark', () {
    test('fromFirestore reads every field', () {
      final added = DateTime.utc(2026, 9, 8);
      final bookmark = KatanaBookmark.fromFirestore({
        'slug': 'eleceed',
        'title': 'Eleceed',
        'coverUrl': 'https://img/eleceed.jpg',
        'status': 'ongoing',
        'addedAt': Timestamp.fromDate(added),
        'lastReadChapterId': 'c400',
        'lastReadPage': 12,
        'lastReadChapterTitle': 'Chapter 400',
        'latestChapterTitle': 'Chapter 418',
        'recommendedBy': 'khentsgdz',
        'recommendationNote': 'You will love this',
      }, 'eleceed');

      expect(bookmark.slug, 'eleceed');
      expect(bookmark.title, 'Eleceed');
      expect(bookmark.addedAt.millisecondsSinceEpoch,
          added.millisecondsSinceEpoch);
      expect(bookmark.lastReadPage, 12);
      expect(bookmark.hasProgress, isTrue);
      expect(bookmark.isRecommended, isTrue);
    });

    test('fromFirestore falls back to the document id for slug', () {
      final bookmark = KatanaBookmark.fromFirestore({
        'title': 'Solo Leveling',
        'addedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 8)),
      }, 'solo-leveling');

      expect(bookmark.slug, 'solo-leveling');
      expect(bookmark.status, 'ongoing');
      expect(bookmark.hasProgress, isFalse);
      expect(bookmark.isRecommended, isFalse);
    });

    test('fromFirestore never crashes on odd field types', () {
      final bookmark = KatanaBookmark.fromFirestore({
        'slug': 1,
        'title': 42,
        'coverUrl': true,
        'status': ['ongoing'],
        'addedAt': 'not-a-date',
        'lastReadChapterId': 400,
        'lastReadPage': 'twelve',
        'lastReadChapterTitle': 7,
        'latestChapterTitle': 8,
        'recommendedBy': 9,
        'recommendationNote': ['note'],
      }, 'eleceed');

      expect(bookmark.slug, 'eleceed');
      expect(bookmark.title, isEmpty);
      expect(bookmark.coverUrl, isEmpty);
      expect(bookmark.status, 'ongoing');
      expect(bookmark.addedAt, isA<DateTime>());
      expect(bookmark.lastReadChapterId, isEmpty);
      expect(bookmark.lastReadPage, 0);
      expect(bookmark.hasProgress, isFalse);
      expect(bookmark.isRecommended, isFalse);
    });
  });
}
