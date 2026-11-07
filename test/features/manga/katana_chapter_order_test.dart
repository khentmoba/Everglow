import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';

void main() {
  test('volume chapter ids parse to real chapter numbers', () {
    expect(katanaChapterNumFromId('v6c147'), '147');
    expect(katanaChapterNumFromId('c528.5'), '528.5');
    expect(katanaChapterNumFromId('c1'), '1');
    expect(katanaChapterNumFromId('fc'), '');
  });

  test('senyuu-style chapter list sorts oldest first, stable', () {
    final scraped = [
      KatanaChapter(id: 'v6c147', num: katanaChapterNumFromId('v6c147'), title: 'Vol.6 Chapter 147'),
      KatanaChapter(id: 'v6c146', num: katanaChapterNumFromId('v6c146'), title: 'Vol.6 Chapter 146'),
      const KatanaChapter(id: 'fc', num: '', title: 'Chapter 1'),
      KatanaChapter(id: 'v1c2', num: katanaChapterNumFromId('v1c2'), title: 'Vol.1 Chapter 2'),
      KatanaChapter(id: 'v1c1', num: katanaChapterNumFromId('v1c1'), title: 'Vol.1 Chapter 1'),
    ];
    final asc = sortChaptersAscending(scraped);
    expect(asc.map((c) => c.id).toList(), ['fc', 'v1c1', 'v1c2', 'v6c146', 'v6c147']);
    final again = sortChaptersAscending(scraped);
    expect(again.map((c) => c.id).toList(), asc.map((c) => c.id).toList());
  });

  group('nextUnreadChapter', () {
    final chapters = [
      const KatanaChapter(id: 'c1', num: '1', title: 'Chapter 1'),
      const KatanaChapter(id: 'c2', num: '2', title: 'Chapter 2'),
      const KatanaChapter(id: 'c3', num: '3', title: 'Chapter 3'),
    ];

    test('a fresh series continues from the first chapter', () {
      expect(nextUnreadChapter(chapters, const {})?.id, 'c1');
    });

    test('continues from the first unfinished chapter', () {
      expect(nextUnreadChapter(chapters, const {'c1'})?.id, 'c2');
      expect(nextUnreadChapter(chapters, const {'c1', 'c2'})?.id, 'c3');
    });

    test('a gap left by jumping around is the continue target', () {
      // Read 1 and 3 out of order: chapter 2 is still the one left.
      expect(nextUnreadChapter(chapters, const {'c1', 'c3'})?.id, 'c2');
    });

    test('a fully read series falls back to the last chapter', () {
      expect(
        nextUnreadChapter(chapters, const {'c1', 'c2', 'c3'})?.id,
        'c3',
      );
    });

    test('an empty series has no continue target', () {
      expect(nextUnreadChapter(const [], const {}), isNull);
    });

    test('a record without read marks falls back to the last read chapter', () {
      // Bookmarks written before read marks existed have an empty set but
      // do know where she stopped. Continuing from chapter 1 would open the
      // wrong chapter and overwrite that resume point.
      expect(
        nextUnreadChapter(
          chapters,
          const {},
          lastReadChapterId: 'c2',
        )?.id,
        'c2',
      );
    });

    test('read marks win over the last read chapter', () {
      // The anchor is c3, so continuing never goes back to c2.
      expect(
        nextUnreadChapter(
          chapters,
          const {'c1'},
          lastReadChapterId: 'c3',
        )?.id,
        'c3',
      );
    });

    test('finishing the last read chapter continues forward', () {
      // The blocker: once c2 was finished, readChapterIds was non-empty, so
      // the old fallback stopped applying and Continue went back to c1 —
      // overwriting the real resume point.
      expect(
        nextUnreadChapter(
          chapters,
          const {'c2'},
          lastReadChapterId: 'c2',
        )?.id,
        'c3',
      );
    });

    test('a gap before the anchor is not reopened', () {
      expect(
        nextUnreadChapter(
          chapters,
          const {'c3'},
          lastReadChapterId: 'c3',
        )?.id,
        'c3',
      );
    });

    test('an unknown last read chapter falls back to the first', () {
      expect(
        nextUnreadChapter(
          chapters,
          const {},
          lastReadChapterId: 'gone',
        )?.id,
        'c1',
      );
    });
  });
}
