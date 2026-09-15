import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';

/// The chapter table used to silently drop chapters: rows the site
/// marks as "Go to" jump targets carry the chapter id in `data-jump`
/// (`<tr data-jump="c30">`) instead of a number, and volume chapters
/// link to `v6c147`-style paths. Both shapes were skipped, so a
/// 31-chapter manga showed only 27 (Chapter 30 among the missing).
void main() {
  const rows = '''
<tr data-jump="c30"><td><div class="chapter"><a href="https://mangakatana.com/manga/some-manga.1/c30">Chapter 30: The Final Day</a></div></td><td><div class="update_time">Sep-14-2026</div></td></tr>
<tr data-jump="0"><td><div class="chapter"><a href="https://mangakatana.com/manga/some-manga.1/c29">Chapter 29: The Drought</a></div></td><td><div class="update_time">Sep-14-2026</div></td></tr>
<tr data-jump="v2c13"><td><div class="chapter"><a href="https://mangakatana.com/manga/dr-slump.2520/v18c16">Vol.18 Chapter 16</a></div></td><td><div class="update_time">Sep-01-2018</div></td></tr>
<tr data-jump="0"><td><div class="chapter"><a href="https://mangakatana.com/manga/dr-slump.2520/v18c15">Vol.18 Chapter 15</a></div></td><td><div class="update_time">Sep-01-2018</div></td></tr>
<tr data-jump="0"><td><div class="chapter"><a href="https://mangakatana.com/manga/some-manga.1/c85.5">Chapter 85.5: Extra</a></div></td><td><div class="update_time">Aug-01-2026</div></td></tr>
<tr data-jump="0"><td><div class="chapter"><a href="https://mangakatana.com/manga/some-manga.1/c38-p11">Chapter 38 - Part 11</a></div></td><td><div class="update_time">Aug-01-2026</div></td></tr>
<tr data-jump="0"><td><div class="chapter"><a href="https://mangakatana.com/manga/some-manga.1/fc">First Chapter</a></div></td><td><div class="update_time">Jan-01-2020</div></td></tr>
''';

  test('parses every chapter row shape, including jump targets', () {
    final chapters = KatanaService.parseChapterTable(rows);
    expect(
      chapters.map((c) => c.id).toList(),
      ['c30', 'c29', 'v18c16', 'v18c15', 'c85.5', 'c38-p11', 'fc'],
    );
  });

  test('jump-target rows keep their titles and dates', () {
    final chapters = KatanaService.parseChapterTable(rows);
    final c30 = chapters.firstWhere((c) => c.id == 'c30');
    expect(c30.title, contains('Final Day'));
    expect(c30.num, '30');
    expect(c30.updateAt, isNotNull);
  });

  test('volume chapter ids keep their real chapter numbers', () {
    final chapters = KatanaService.parseChapterTable(rows);
    final vol = chapters.firstWhere((c) => c.id == 'v18c16');
    expect(vol.num, '16');
    expect(vol.title, contains('Vol.18'));
  });
}
