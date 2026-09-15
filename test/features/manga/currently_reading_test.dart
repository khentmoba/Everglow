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
}
