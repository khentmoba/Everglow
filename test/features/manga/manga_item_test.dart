import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/data/models/manga_item.dart';

void main() {
  group('MangaItem', () {
    test('contentType maps original language to content type', () {
      // Verified via fromFirestore to reuse the default-arg path.
      MangaItem item(String lang) => MangaItem.fromFirestore({
            'mangaId': 'hid1',
            'title': 'T',
            'originalLanguage': lang,
          }, 'doc1');

      expect(item('jp').contentType, 'Manga');
      expect(item('ja').contentType, 'Manga');
      expect(item('ko').contentType, 'Manhwa');
      expect(item('zh').contentType, 'Manhua');
      expect(item('cn').contentType, 'Manhua');
      expect(item('en').contentType, 'Other');
    });

    test('library status getters reflect libraryStatus', () {
      final item = MangaItem.fromFirestore({
        'mangaId': 'hid1',
        'title': 'T',
        'libraryStatus': 'reading',
      }, 'doc1');

      expect(item.isInLibrary, isTrue);
      expect(item.isReading, isTrue);
      expect(item.isPlanToRead, isFalse);
      expect(item.libraryDisplay, 'Reading');
    });

    test('not-in-library item defaults to Add to Library', () {
      final item = MangaItem.fromFirestore({
        'mangaId': 'hid1',
        'title': 'T',
      }, 'doc1');

      expect(item.isInLibrary, isFalse);
      expect(item.libraryDisplay, 'Add to Library');
    });

    test('toFirestore/fromFirestore round-trips every field', () {
      final addedAt = DateTime.utc(2026, 8, 14, 12, 30);
      final item = MangaItem(
        id: 'doc1',
        mangaId: 'hid-abc',
        title: 'Eleceed',
        author: 'Son Je-ho',
        artist: 'ZHENA',
        description: 'A fast manhwa.',
        coverUrl: 'https://example.com/cover.jpg',
        year: '2018',
        status: 'ongoing',
        originalLanguage: 'ko',
        contentRating: 'safe',
        tags: const ['action', 'comedy'],
        userName: 'khentsgdz',
        addedAt: addedAt,
        libraryStatus: 'reading',
        lastReadChapterId: 'ch-409',
        lastReadPage: 12,
        comickId: 42,
        comickSlug: 'eleceed',
        mangaKakalotId: 'eleceed',
        rating: 9.1,
        followCount: 1234,
        altTitles: const ['The God of High School', 'Einheld'],
      );

      final data = item.toFirestore();
      expect(data['addedAt'], isA<Timestamp>());

      final restored = MangaItem.fromFirestore(data, 'doc1');
      expect(restored.mangaId, item.mangaId);
      expect(restored.title, item.title);
      expect(restored.author, item.author);
      expect(restored.artist, item.artist);
      expect(restored.description, item.description);
      expect(restored.coverUrl, item.coverUrl);
      expect(restored.year, item.year);
      expect(restored.status, item.status);
      expect(restored.originalLanguage, item.originalLanguage);
      expect(restored.contentRating, item.contentRating);
      expect(restored.tags, item.tags);
      expect(restored.userName, item.userName);
      // Timestamp.toDate() returns local time; compare epoch millis.
      expect(restored.addedAt.millisecondsSinceEpoch,
          addedAt.millisecondsSinceEpoch);
      expect(restored.libraryStatus, item.libraryStatus);
      expect(restored.lastReadChapterId, item.lastReadChapterId);
      expect(restored.lastReadPage, item.lastReadPage);
      expect(restored.comickId, item.comickId);
      expect(restored.comickSlug, item.comickSlug);
      expect(restored.mangaKakalotId, item.mangaKakalotId);
      expect(restored.rating, item.rating);
      expect(restored.followCount, item.followCount);
      expect(restored.altTitles, item.altTitles);
    });

    test('fromFirestore falls back to mangaDexId for kakalot id', () {
      final item = MangaItem.fromFirestore({
        'mangaId': 'hid1',
        'title': 'T',
        'mangaDexId': 'legacy-dex-id',
      }, 'doc1');

      expect(item.mangaKakalotId, 'legacy-dex-id');
    });

    test('copyWith overrides only provided fields', () {
      final base = MangaItem(
        id: 'doc1',
        mangaId: 'hid1',
        title: 'Original',
        libraryStatus: 'reading',
        addedAt: DateTime.utc(2026, 1, 1),
      );

      final updated = base.copyWith(
        title: 'Updated',
        libraryStatus: 'completed',
        lastReadPage: 7,
      );

      expect(updated.title, 'Updated');
      expect(updated.libraryStatus, 'completed');
      expect(updated.lastReadPage, 7);
      expect(updated.mangaId, base.mangaId);
      expect(updated.addedAt, base.addedAt);
      expect(updated.rating, base.rating);
    });
  });

  group('MangaChapter', () {
    test('displayTitle combines chapter number and title', () {
      final chapter = MangaChapter(
        id: 'c415',
        chapter: '415',
        title: 'The Battle Begins',
        publishAt: DateTime.utc(2026, 1, 1),
      );

      expect(chapter.displayTitle, 'Ch. 415 — The Battle Begins');
      expect(chapter.shortLabel, 'Ch. 415');
    });

    test('shortLabel falls back to Oneshot when no number', () {
      final chapter = MangaChapter(
        id: 'oneshot',
        title: 'Special',
        publishAt: DateTime.utc(2026, 1, 1),
      );

      expect(chapter.shortLabel, 'Oneshot');
    });

    test('fromApi extracts scanlation group from relationships', () {
      final chapter = MangaChapter.fromApi(
        {
          'chapter': '415',
          'title': 'The Battle Begins',
          'pages': 55,
          'translatedLanguage': 'en',
          'publishAt': '2026-01-01T00:00:00.000Z',
        },
        {
          'id': 'rel-1',
          'relationships': [
            {
              'type': 'scanlation_group',
              'attributes': {'name': 'Hatigarm Scans'},
            },
          ],
        },
      );

      expect(chapter.id, 'rel-1');
      expect(chapter.chapter, '415');
      expect(chapter.pages, 55);
      expect(chapter.scanlationGroup, 'Hatigarm Scans');
      expect(chapter.publishAt, DateTime.utc(2026, 1, 1));
    });

    test('fromApi tolerates missing fields', () {
      final chapter = MangaChapter.fromApi({}, {});

      expect(chapter.id, '');
      expect(chapter.pages, 0);
      expect(chapter.translatedLanguage, 'en');
      expect(chapter.scanlationGroup, '');
    });
  });

  group('MangaChapterPages', () {
    test('urlForPage builds data URLs from base + hash + filename', () {
      final pages = MangaChapterPages(
        chapterId: 'ch1',
        baseUrl: 'https://uploads.example.com',
        hash: 'abc123',
        filenames: const ['001.jpg', '002.jpg'],
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(pages.urlForPage(0), 'https://uploads.example.com/data/abc123/001.jpg');
      expect(pages.urlForPage(1), 'https://uploads.example.com/data/abc123/002.jpg');
    });

    test('urlForPage treats filenames as direct URLs when base is empty', () {
      final pages = MangaChapterPages(
        chapterId: 'ch1',
        baseUrl: '',
        hash: '',
        filenames: const ['https://cdn.example.com/001.jpg'],
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(pages.urlForPage(0), 'https://cdn.example.com/001.jpg');
    });

    test('urlForPage returns empty string for out-of-range pages', () {
      final pages = MangaChapterPages(
        chapterId: 'ch1',
        baseUrl: 'https://uploads.example.com',
        hash: 'abc123',
        filenames: const ['001.jpg'],
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(pages.urlForPage(-1), '');
      expect(pages.urlForPage(1), '');
    });
  });
}
