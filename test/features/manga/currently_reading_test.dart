import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/presentation/katana/currently_reading_shelf.dart';
import 'package:flutter_test/flutter_test.dart';

MangaItem _readingItem({
  required String mangaId,
  String kakalotId = '',
  String title = 'Solo Leveling',
  String lastChapter = '',
  int lastPage = 0,
}) {
  return MangaItem(
    id: 'doc1',
    mangaId: mangaId,
    title: title,
    userName: 'clairjassen',
    addedAt: DateTime(2026, 1, 1),
    libraryStatus: 'reading',
    lastReadChapterId: lastChapter,
    lastReadPage: lastPage,
    mangaKakalotId: kakalotId,
  );
}

void main() {
  group('katanaSlugOfItem', () {
    test('extracts slug from katana| prefix', () {
      final item = _readingItem(mangaId: 'katana|solo-leveling');
      expect(katanaSlugOfItem(item), 'solo-leveling');
    });

    test('falls back to mangaKakalotId for legacy entries', () {
      final item = _readingItem(
        mangaId: 'some-old-id',
        kakalotId: 'one-piece',
      );
      expect(katanaSlugOfItem(item), 'one-piece');
    });

    test('returns empty when no slug is stored', () {
      final item = _readingItem(mangaId: 'some-old-id');
      expect(katanaSlugOfItem(item), isEmpty);
    });
  });

  group('Currently Reading library model', () {
    test('reading entries report isReading', () {
      final item = _readingItem(mangaId: 'katana|solo-leveling');
      expect(item.isReading, isTrue);
      expect(item.libraryDisplay, 'Reading');
    });

    test('non-reading entries are excluded by the shelf filter', () {
      final items = [
        _readingItem(mangaId: 'katana|solo-leveling'),
        MangaItem(
          id: 'doc2',
          mangaId: 'katana|one-piece',
          title: 'One Piece',
          userName: 'clairjassen',
          addedAt: DateTime(2026, 1, 2),
          libraryStatus: 'plan-to-read',
        ),
      ];
      final reading = items.where((i) => i.isReading).toList();
      expect(reading, hasLength(1));
      expect(reading.first.title, 'Solo Leveling');
    });

    test('progress line inputs survive empty titles', () {
      final item = _readingItem(
        mangaId: 'katana|solo-leveling',
        title: '',
        lastChapter: 'c12',
        lastPage: 5,
      );
      expect(item.title, isEmpty);
      expect(item.lastReadChapterId, 'c12');
      expect(item.lastReadPage, 5);
    });
  });

  KatanaBookmark bookmark({
    required String slug,
    String title = '',
    String chapterId = '',
    int page = 0,
  }) {
    return KatanaBookmark(
      slug: slug,
      title: title,
      coverUrl: '',
      addedAt: DateTime(2026, 1, 2),
      lastReadChapterId: chapterId,
      lastReadPage: page,
    );
  }

  group('humanizeKatanaSlug', () {
    test('title-cases slug words', () {
      expect(
        humanizeKatanaSlug('chronicles-of-the-lazy-sovereign'),
        'Chronicles Of The Lazy Sovereign',
      );
    });

    test('falls back for empty slugs', () {
      expect(humanizeKatanaSlug('  '), 'Untitled series');
    });
  });

  group('mergeReadingWithProgress', () {
    test('appends progress-only titles after pinned entries', () {
      final merged = mergeReadingWithProgress(
        reading: [_readingItem(mangaId: 'katana|solo-leveling')],
        bookmarks: [
          bookmark(slug: 'lazy-sovereign', chapterId: 'c2', page: 1),
        ],
        userName: 'clairjassen',
      );
      expect(merged, hasLength(2));
      expect(merged.first.title, 'Solo Leveling');
      final extra = merged.last;
      expect(extra.mangaId, 'katana|lazy-sovereign');
      expect(extra.title, 'Lazy Sovereign');
      expect(extra.lastReadChapterId, 'c2');
      expect(extra.lastReadPage, 1);
      // Display-only: no library entry, so no Remove button.
      expect(extra.isReading, isFalse);
      expect(katanaSlugOfItem(extra), 'lazy-sovereign');
    });

    test('skips bookmarks already pinned as Reading', () {
      final merged = mergeReadingWithProgress(
        reading: [_readingItem(mangaId: 'katana|solo-leveling')],
        bookmarks: [
          bookmark(
            slug: 'solo-leveling',
            title: 'Solo Leveling',
            chapterId: 'c12',
            page: 5,
          ),
        ],
        userName: 'clairjassen',
      );
      expect(merged, hasLength(1));
      expect(merged.first.title, 'Solo Leveling');
    });

    test('skips bookmarks without progress', () {
      final merged = mergeReadingWithProgress(
        reading: const [],
        bookmarks: [bookmark(slug: 'just-bookmarked')],
        userName: 'clairjassen',
      );
      expect(merged, isEmpty);
    });

    test('keeps saved titles over humanized slugs', () {
      final merged = mergeReadingWithProgress(
        reading: const [],
        bookmarks: [
          bookmark(
            slug: 'lazy-sovereign',
            title: 'Chronicles of the Lazy Sovereign',
            chapterId: 'c2',
          ),
        ],
        userName: 'clairjassen',
      );
      expect(merged, hasLength(1));
      expect(merged.first.title, 'Chronicles of the Lazy Sovereign');
    });
  });
}
