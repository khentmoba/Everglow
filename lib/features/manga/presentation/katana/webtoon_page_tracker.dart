/// Maps a webtoon chapter's scroll offset to a page number, and back.
///
/// A webtoon chapter is one continuous strip where every page can have a
/// different height. The reader used to guess the page from a plain
/// `offset / maxScrollExtent` ratio, which lands on the wrong page as soon
/// as a chapter mixes a tall spread with short panels — the page pill lied
/// and "continue reading" reopened in the wrong place.
///
/// This tracks each page's real laid-out height as it scrolls past and
/// fills in pages that have not been built yet with the median of the
/// heights it has already seen. The result is exact for every page Clair
/// has actually scrolled through, and a close estimate ahead of her that
/// self-corrects as more pages load.
class WebtoonPageTracker {
  WebtoonPageTracker({this.defaultPageHeight = 800});

  /// Height assumed for every page before any has been measured.
  final double defaultPageHeight;

  int _pageCount = 0;
  final Map<int, double> _measured = {};
  double? _medianCache;

  int get pageCount => _pageCount;

  /// Number of pages whose real height is known.
  int get measuredCount => _measured.length;

  /// Starts a fresh chapter. Measured heights from the previous chapter
  /// must not leak into the next one.
  void reset(int pageCount) {
    _pageCount = pageCount < 0 ? 0 : pageCount;
    _measured.clear();
    _medianCache = null;
  }

  /// Records the real height of page [index] after layout.
  void measure(int index, double height) {
    if (index < 0 || index >= _pageCount) return;
    if (!height.isFinite || height <= 0) return;
    if (_measured[index] == height) return;
    _measured[index] = height;
    _medianCache = null;
  }

  /// The height of page [index]: measured when known, otherwise the
  /// median of the measured pages, otherwise [defaultPageHeight].
  double heightOf(int index) => _measured[index] ?? estimatedPageHeight;

  /// Median height of the pages measured so far. Median rather than mean
  /// so one tall double-page spread cannot drag the estimate for every
  /// page after it.
  double get estimatedPageHeight {
    final cached = _medianCache;
    if (cached != null) return cached;
    if (_measured.isEmpty) return defaultPageHeight;
    final heights = _measured.values.toList()..sort();
    final middle = heights.length ~/ 2;
    final median = heights.length.isOdd
        ? heights[middle]
        : (heights[middle - 1] + heights[middle]) / 2;
    _medianCache = median;
    return median;
  }

  /// Distance from the top of the strip to the top of page [index].
  double offsetForPage(int index) {
    if (index <= 0) return 0;
    final end = index > _pageCount ? _pageCount : index;
    var offset = 0.0;
    for (var i = 0; i < end; i++) {
      offset += heightOf(i);
    }
    return offset;
  }

  /// The 0-based page containing [offset], clamped to the chapter.
  int pageAtOffset(double offset) {
    if (_pageCount <= 0) return 0;
    if (!offset.isFinite || offset <= 0) return 0;
    var remaining = offset;
    for (var i = 0; i < _pageCount; i++) {
      final height = heightOf(i);
      if (remaining < height) return i;
      remaining -= height;
    }
    return _pageCount - 1;
  }

  /// Total height of the strip using the current best knowledge.
  double get totalHeight => offsetForPage(_pageCount);
}
