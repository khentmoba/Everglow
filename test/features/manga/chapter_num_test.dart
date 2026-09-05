import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/data/models/chapter_num.dart';

void main() {
  test('normalizeChapterNum unifies 1, 1.0 and 001', () {
    expect(normalizeChapterNum('1'), '1');
    expect(normalizeChapterNum('1.0'), '1');
    expect(normalizeChapterNum('001'), '1');
    expect(normalizeChapterNum('12.5'), '12.5');
  });

  test('normalizeChapterNum passes through empties and specials', () {
    expect(normalizeChapterNum(''), '');
    expect(normalizeChapterNum('Special'), 'Special');
  });

  test('chaptersMatch tolerates formatting', () {
    expect(chaptersMatch('1', '1.0'), isTrue);
    expect(chaptersMatch('001', '1'), isTrue);
    expect(chaptersMatch('1', '2'), isFalse);
    expect(chaptersMatch('Special', 'Special'), isTrue);
    expect(chaptersMatch('Special', 'Extra'), isFalse);
  });

  test('chapterNumValue parses or falls back to zero', () {
    expect(chapterNumValue('12'), 12);
    expect(chapterNumValue('12.5'), 12.5);
    expect(chapterNumValue('Special'), 0);
    expect(chapterNumValue(''), 0);
  });

  test('chapter numbers sort in reading order', () {
    final chapters = ['10', '2', '1.5', '1', 'Special'];
    chapters.sort((a, b) => chapterNumValue(a).compareTo(chapterNumValue(b)));
    expect(chapters.first, 'Special'); // 0 sorts first, like before
    expect(chapters.sublist(1), ['1', '1.5', '2', '10']);
  });
}
