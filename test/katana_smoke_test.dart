import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';

/// Live smoke test for the Manga Katana scraper. Hits the deployed
/// proxy Cloud Functions, so it needs network access.
void main() {
  test('katana catalog smoke', () async {
    final service = KatanaService();

    final home = await service.fetchHome();
    expect(home.latest, isNotEmpty, reason: 'home latest items');
    expect(home.hot, isNotEmpty, reason: 'home hot rail');
    expect(home.genres, isNotEmpty, reason: 'home genres');
    final first = home.latest.first;
    expect(first.title, isNotEmpty);
    expect(first.slug, isNotEmpty);
    expect(first.coverUrl, isNotEmpty);
    expect(first.latestChapter, isNotNull);
    // ignore: avoid_print
    print(
      'HOME ${home.latest.length} latest, ${home.hot.length} hot, '
      'first="${first.title}" chapters=${first.recentChapters.length}',
    );

    final dir = await service.fetchCatalog(
      mode: 'directory',
      include: const ['action'],
      orderBy: 'az',
    );
    expect(dir.items, isNotEmpty, reason: 'directory filtered items');
    // ignore: avoid_print
    print(
      'DIRECTORY action+az: ${dir.items.length} items, '
      'first="${dir.items.first.title}"',
    );

    final genre = await service.fetchCatalog(mode: 'genre', key: 'manhwa');
    expect(genre.items, isNotEmpty, reason: 'genre items');
    // ignore: avoid_print
    print('GENRE manhwa: ${genre.items.length} items');

    final search = await service.fetchCatalog(mode: 'search', query: 'eleceed');
    expect(search.items, isNotEmpty, reason: 'search items');
    // ignore: avoid_print
    print(
      'SEARCH eleceed: ${search.items.length} items, '
      'first="${search.items.first.title}"',
    );

    final suggestions = await service.fetchSuggestions('eleceed');
    expect(suggestions, isNotEmpty, reason: 'suggestions');
    // ignore: avoid_print
    print('SUGGESTIONS: ${suggestions.length}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('katana detail + chapter smoke', () async {
    final service = KatanaService();
    final detail = await service.fetchMangaDetail('eleceed.115');
    expect(detail, isNotNull);
    expect(detail!.chapters, isNotEmpty, reason: 'detail chapters');
    expect(detail.title, 'Eleceed');
    expect(detail.authors, isNotEmpty);
    expect(detail.genres, isNotEmpty);
    // ignore: avoid_print
    print(
      'DETAIL ${detail.title}: ${detail.chapters.length} chapters, '
      'first="${detail.chapters.first.displayTitle}"',
    );

    final pages = await service.fetchChapterPages(
      'eleceed.115',
      detail.chapters.first.path,
    );
    expect(pages, isNotEmpty, reason: 'chapter pages');
    final firstPage = pages.first;
    // ignore: avoid_print
    print(
      'CHAPTER pages: ${pages.length}, first='
      '${firstPage.length > 70 ? firstPage.substring(0, 70) : firstPage}',
    );

    final fcPages = await service.fetchChapterPages('eleceed.115', 'fc');
    expect(fcPages, isNotEmpty, reason: 'first chapter pages');
    // ignore: avoid_print
    print('CHAPTER fc pages: ${fcPages.length}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
