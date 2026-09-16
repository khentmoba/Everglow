import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/mangakatana_service.dart';

/// The detail page embeds other series (Latest Updates rail, Hot Manga,
/// recommendations). The chapter parser used to accept every
/// `/manga/*/cNNN` link on the page, so foreign chapters (e.g. Ch. 1075
/// or Ch. 462 from other series) polluted the list with huge gaps —
/// "Ch. 385 suddenly goes to Ch. 462".
void main() {
  const slug = 'i-am-the-fated-villain.26054';
  const html = '''
<div class="chapter"><a href="https://mangakatana.com/manga/i-am-the-fated-villain.26054/c385">Chapter 385</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/i-am-the-fated-villain.26054/c326">Chapter 326</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/yuan-zun.19861/c462">Chapter 462</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/apotheosis.19829/c1293">Chapter 1293</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/i-am-the-fated-villain.26054/v6c147">Vol.6 Chapter 147</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/i-am-the-fated-villain.26054/c38-p11">Chapter 38 - Part 11</a></div>
<div class="chapter"><a href="https://mangakatana.com/manga/i-am-the-fated-villain.26054/fc">First Chapter</a></div>
''';

  test('keeps only chapters of the requested series', () {
    final chapters = MangakatanaService.parseChapterList(html, slug);
    final nums = chapters.map((c) => c.chapter).toList();
    expect(nums, containsAll(['385', '326', '147']));
    expect(nums, isNot(contains('462')));
    expect(nums, isNot(contains('1293')));
    expect(chapters.length, 5);
  });

  test('part-suffixed ids sort numerically, fc sorts first', () {
    final chapters = MangakatanaService.parseChapterList(html, slug);
    final byId = {for (final c in chapters) c.id.split('/').last: c.chapter};
    expect(byId['c38-p11'], '38');
    expect(byId['fc'], '0');
    expect(byId['v6c147'], '147');
  });
}
