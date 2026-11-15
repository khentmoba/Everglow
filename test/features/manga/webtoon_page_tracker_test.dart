import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/presentation/katana/webtoon_page_tracker.dart';

void main() {
  group('WebtoonPageTracker', () {
    test('starts empty and reports the default height for every page', () {
      final tracker = WebtoonPageTracker(defaultPageHeight: 800)
        ..reset(10);

      expect(tracker.pageCount, 10);
      expect(tracker.measuredCount, 0);
      expect(tracker.estimatedPageHeight, 800);
      expect(tracker.heightOf(4), 800);
      expect(tracker.totalHeight, 8000);
    });

    test('uses measured heights instead of the default', () {
      final tracker = WebtoonPageTracker(defaultPageHeight: 800)
        ..reset(3)
        ..measure(0, 3000)
        ..measure(1, 900)
        ..measure(2, 900);

      expect(tracker.measuredCount, 3);
      expect(tracker.heightOf(0), 3000);
      expect(tracker.offsetForPage(1), 3000);
      expect(tracker.offsetForPage(2), 3900);
      expect(tracker.totalHeight, 4800);
    });

    test('pageAtOffset walks real heights, not a linear ratio', () {
      final tracker = WebtoonPageTracker(defaultPageHeight: 800)
        ..reset(3)
        ..measure(0, 3000)
        ..measure(1, 900)
        ..measure(2, 900);

      expect(tracker.pageAtOffset(0), 0);
      expect(tracker.pageAtOffset(2999), 0);
      expect(tracker.pageAtOffset(3000), 1);
      expect(tracker.pageAtOffset(3899), 1);
      expect(tracker.pageAtOffset(3900), 2);
      expect(tracker.pageAtOffset(100000), 2, reason: 'clamped to last page');
    });

    test('estimates unmeasured pages from the median, not the mean', () {
      final tracker = WebtoonPageTracker(defaultPageHeight: 800)
        ..reset(10)
        ..measure(0, 4000)
        ..measure(1, 900)
        ..measure(2, 900)
        ..measure(3, 900);

      expect(tracker.estimatedPageHeight, 900);
      expect(tracker.heightOf(9), 900);
      expect(tracker.offsetForPage(5), 4000 + 900 * 4);
    });

    test('offsetForPage and pageAtOffset round-trip', () {
      final tracker = WebtoonPageTracker()..reset(5);
      tracker
        ..measure(0, 1200)
        ..measure(1, 640)
        ..measure(2, 2100)
        ..measure(3, 800)
        ..measure(4, 950);

      for (var page = 0; page < 5; page++) {
        expect(
          tracker.pageAtOffset(tracker.offsetForPage(page)),
          page,
          reason: 'page $page should round-trip',
        );
      }
    });

    test('ignores unusable measurements and out-of-range indexes', () {
      final tracker = WebtoonPageTracker(defaultPageHeight: 800)..reset(2);

      tracker
        ..measure(-1, 500)
        ..measure(5, 500)
        ..measure(0, 0)
        ..measure(0, -20)
        ..measure(0, double.nan)
        ..measure(0, double.infinity);

      expect(tracker.measuredCount, 0);
      expect(tracker.heightOf(0), 800);
    });

    test('reset clears the previous chapter', () {
      final tracker = WebtoonPageTracker()..reset(3);
      tracker
        ..measure(0, 2000)
        ..measure(1, 2000)
        ..measure(2, 2000);
      expect(tracker.totalHeight, 6000);

      tracker.reset(4);
      expect(tracker.pageCount, 4);
      expect(tracker.measuredCount, 0);
      expect(tracker.totalHeight, 800 * 4);
    });

    test('an empty chapter never throws', () {
      final tracker = WebtoonPageTracker()..reset(0);

      expect(tracker.pageAtOffset(500), 0);
      expect(tracker.offsetForPage(3), 0);
      expect(tracker.totalHeight, 0);
    });

    test('re-measuring the same height keeps the median cache valid', () {
      final tracker = WebtoonPageTracker()..reset(4);
      tracker
        ..measure(0, 1000)
        ..measure(1, 1000);
      expect(tracker.estimatedPageHeight, 1000);

      tracker.measure(0, 1000);
      expect(tracker.estimatedPageHeight, 1000);
      expect(tracker.measuredCount, 2);
    });
  });
}
