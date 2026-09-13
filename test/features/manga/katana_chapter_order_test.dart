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
}
