class WebtoonPageTracker {
  WebtoonPageTracker({this.defaultPageHeight = 800});

  final double defaultPageHeight;

  int _pageCount = 0;
  final Map<int, double> _measured = {};
  double? _medianCache;

  int get pageCount => _pageCount;

  int get measuredCount => _measured.length;

  void reset(int pageCount) {
    _pageCount = pageCount < 0 ? 0 : pageCount;
    _measured.clear();
    _medianCache = null;
  }

  void measure(int index, double height) {
    if (index < 0 || index >= _pageCount) return;
    if (!height.isFinite || height <= 0) return;
    if (_measured[index] == height) return;
    _measured[index] = height;
    _medianCache = null;
  }

  double heightOf(int index) => _measured[index] ?? estimatedPageHeight;

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

  double offsetForPage(int index) {
    if (index <= 0) return 0;
    final end = index > _pageCount ? _pageCount : index;
    var offset = 0.0;
    for (var i = 0; i < end; i++) {
      offset += heightOf(i);
    }
    return offset;
  }

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

  double get totalHeight => offsetForPage(_pageCount);
}
