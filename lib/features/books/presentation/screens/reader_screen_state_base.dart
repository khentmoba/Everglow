part of 'reader_screen_web.dart';

abstract class _ReaderScreenStateBase extends State<ReaderScreen> {
  final OpenLibraryService _service = OpenLibraryService();
  final WebTtsService _tts = WebTtsService.instance;

  bool _isLoading = true;
  String? _loadError;
  List<BookChapter> _chapters = const [];
  final Map<int, List<String>> _paragraphCache = {};
  int _currentChapter = 0;
  double _fontSize = 17.0;
  ReaderMode _readerMode = ReaderMode.text;
  late final String _viewType;
  static int _viewTypeCounter = 0;
  ReaderTheme _theme = ReaderTheme.dark;

  // Persisted state keys
  String get _progressKey => 'reader_progress::${widget.book.workKey}';

  /// Implemented by the screen's state subclass; base loading flows may
  /// need to surface the listen sheet after the first chapter is ready.
  void _showListenSheet();

  @override
  void initState() {
    super.initState();
    _viewType = 'reader-iframe-${_viewTypeCounter++}';
    _loadAndSplit();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadAndSplit() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_progressKey);
    if (saved != null && saved >= 0) {
      _currentChapter = saved;
    }

    // Build the full ordered list of read source candidates. The
    // service tries each one until one responds successfully — that
    // way a CORS block or 404 on the Internet Archive fallback
    // still leaves us with a working Gutenberg or Open Library URL.
    final candidates = _service.buildReadSourceCandidates(widget.book);
    // Gutenberg books and public-domain Internet Archive books get
    // the in-app text reader; borrow-only Internet Archive books
    // (no plain text on disk) fall back to the IA embedded viewer.
    final iaId = widget.book.iaId;
    String? resolvedIaId = iaId;
    if (candidates.isEmpty && iaId.isEmpty && widget.book.workKey.isNotEmpty) {
      resolvedIaId = await _findIaEdition(widget.book.workKey);
      if (resolvedIaId != null) {
        _registerIframe(resolvedIaId);
        if (!mounted) return;
        setState(() {
          _readerMode = ReaderMode.embed;
          _isLoading = false;
        });
        return;
      }
    }
    if (candidates.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'No readable copy available for this title.';
      });
      return;
    }

    try {
      final result = await _service.fetchBookTextFromCandidates(candidates);
      if (!mounted) return;
      if (!result.isSuccess) {
        // Public-domain IA items can still lose the text race (proxy
        // down, mirror 404, redirect to a borrow page). Show the
        // embedded viewer instead of the "no readable text" error.
        final embedIa = resolvedIaId ?? iaId;
        if (embedIa.isNotEmpty && !embedIa.startsWith('pg')) {
          _registerIframe(embedIa);
          if (!mounted) return;
          setState(() {
            _readerMode = ReaderMode.embed;
            _isLoading = false;
          });
          return;
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = result.error ??
                'Could not load the book text from any available source.';
          });
        }
        return;
      }
      if (_looksLikeHtml(result.text)) {
        final embedIa = resolvedIaId ?? iaId;
        if (embedIa.isNotEmpty && !embedIa.startsWith('pg')) {
          _registerIframe(embedIa);
          if (!mounted) return;
          setState(() {
            _readerMode = ReaderMode.embed;
            _isLoading = false;
          });
          return;
        }
      }
      final cleaned = _stripGutenbergBoilerplate(result.text);
      final chapters = await _splitChaptersYielded(cleaned);
      setState(() {
        _chapters = chapters;
        // Clamp currentChapter in case the saved index is now invalid
        if (_currentChapter >= chapters.length) {
          _currentChapter = 0;
        }
        _isLoading = false;
      });
      if (widget.startListening && _chapters.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showListenSheet();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Error: $e';
      });
    }
  }

  /// Find an Internet Archive copy for a work when the search result
  /// didn't carry one. Open Library's editions list includes `ia`
  /// identifiers for borrowable editions.
  Future<String?> _findIaEdition(String workKey) async {
    try {
      final editions = await _service.fetchEditions(workKey);
      for (final edition in editions) {
        final iaRaw = edition['ia'];
        if (iaRaw is List && iaRaw.isNotEmpty) {
          final id = iaRaw.first.toString();
          if (id.isNotEmpty && !id.startsWith('pg')) return id;
        } else if (iaRaw is String && iaRaw.isNotEmpty) {
          return iaRaw;
        }
      }
    } catch (e) {
      Logger.e('Reader IA edition lookup failed ($workKey)', error: e);
    }
    return null;
  }

  /// Guard against a proxied/redirected HTML page (e.g. an Internet
  /// Archive borrow page) being mistaken for book text.
  bool _looksLikeHtml(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase().startsWith('<!doctype') ||
        trimmed.toLowerCase().startsWith('<html')) {
      return true;
    }
    return trimmed.startsWith('<') && trimmed.length < 4096;
  }

  Future<void> _saveProgress(int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, chapter);
  }

  void _registerIframe(String iaId) {
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return html.IFrameElement()
          ..src = 'https://archive.org/stream/$iaId?ui=embed'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none';
      });
    } catch (e) {
      debugPrint('[ReaderScreen] Archive.org iframe registration failed: $e');
    }
  }

  // ── TEXT PROCESSING ────────────────────────────────────────────────

  /// Strip the Project Gutenberg header and footer blocks. They are
  /// delimited by `*** START OF` / `*** END OF` markers that the
  /// Gutenberg convention uses.
  String _stripGutenbergBoilerplate(String raw) {
    final startMatch = RegExp(r'\*\*\*\s*START OF (?:THE|THIS)?\s*PROJECT',
            caseSensitive: false)
        .firstMatch(raw);
    final endMatch = RegExp(r'\*\*\*\s*END OF (?:THE|THIS)?\s*PROJECT',
            caseSensitive: false)
        .firstMatch(raw);
    if (startMatch == null || endMatch == null) return raw;
    return raw.substring(startMatch.end, endMatch.start);
  }

  /// Split a book's plain text into [BookChapter]s.
  ///
  /// Splits book text without holding the UI frame hostage. On native
  /// platforms the heavy regex passes run in an isolate; on web the passes
  /// yield between each phase so the loading frame can paint.
  Future<List<BookChapter>> _splitChaptersYielded(String text) async {
    if (!kIsWeb) {
      final raw = await compute(
        _splitBookTextIsolate,
        [text, widget.book.title],
      );
      return raw
          .map((entry) => BookChapter(title: entry[0], body: entry[1]))
          .toList();
    }

    await Future<void>.delayed(Duration.zero);
    final explicit = _splitOnExplicitMarkers(text);
    if (explicit.length >= 2) return explicit;
    await Future<void>.delayed(Duration.zero);
    final stars = _splitOnStarSeparators(text);
    if (stars.length >= 2) return stars;
    await Future<void>.delayed(Duration.zero);
    return [
      BookChapter(
        title: widget.book.title,
        body: _normalizeWhitespace(text),
      ),
    ];
  }

  List<BookChapter> _splitOnExplicitMarkers(String text) {
    // Find all positions where a "CHAPTER / PART / BOOK / PROLOGUE /
    // EPILOGUE" line starts. We allow a chapter number/roman and an
    // optional title on the same line.
    final pattern = RegExp(
      r'^(CHAPTER|Chapter|PART|Part|BOOK|Book|PROLOGUE|EPILOGUE|Act|ACT)\s+'
      r'([IVXLCDM]+|\d+|[A-Za-z]+)'
      r'(?:[\.\:\s]+([^\n]+))?',
      multiLine: true,
    );

    final matches = pattern.allMatches(text).toList();
    if (matches.length < 2) return const [];

    final chapters = <BookChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final header = text.substring(start, end);
      final headerLines = header.split('\n');
      final title = headerLines.first.trim();
      final body = _normalizeWhitespace(
          headerLines.skip(1).join('\n'));
      if (body.trim().isEmpty) continue;
      chapters.add(BookChapter(title: title, body: body));
    }
    return chapters;
  }

  List<BookChapter> _splitOnStarSeparators(String text) {
    // Gutenberg short stories use centered "***" or "* * *" between
    // sections. We treat each separator as a chapter boundary.
    final parts = text.split(RegExp(r'^\s*\*{3,}\s*$', multiLine: true));
    if (parts.length < 2) return const [];
    final chapters = <BookChapter>[];
    for (var i = 0; i < parts.length; i++) {
      final body = _normalizeWhitespace(parts[i]);
      if (body.trim().isEmpty) continue;
      // Use the first non-empty line as the chapter title.
      final firstLine =
          body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      final title = firstLine.length > 80
          ? '${firstLine.substring(0, 80)}…'
          : firstLine;
      chapters.add(BookChapter(
        title: title.isEmpty ? 'Section ${chapters.length + 1}' : title,
        body: body,
      ));
    }
    return chapters;
  }

  String _normalizeWhitespace(String text) {
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ── UI ─────────────────────────────────────────────────────────────

}
