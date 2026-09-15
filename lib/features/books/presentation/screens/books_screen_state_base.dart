part of 'books_screen.dart';

abstract class _BooksScreenStateBase extends State<BooksScreen> {
  final OpenLibraryService _service = OpenLibraryService();
  final BookCatalogService _catalog = BookCatalogService();
  final BookLibraryService _library = BookLibraryService();
  int _currentIndex = 0;
  int _librarySegment = 0;

  StreamSubscription<List<BookItem>>? _readlistSub;
  StreamSubscription<List<BookItem>>? _favoritesSub;
  StreamSubscription<List<BookItem>>? _historySub;
  List<BookItem> _readlist = [];
  List<BookItem> _toReadList = [];
  List<BookItem> _readHistoryList = [];
  List<BookItem> _favorites = [];
  List<BookItem> _history = [];

  List<BookSearchResult> _popular = [];
  List<BookSearchResult> _recent = [];
  bool _isLoadingHome = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<BookSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  BookSort _searchSort = BookSort.relevant;
  String? _searchFiletype;
  String? _searchLanguage;
  bool _searchRan = false;
  // Z-Lib style paging + advanced filters.
  static const int _searchPageSize = 30;
  int _searchTotal = 0;
  bool _searchHasMore = false;
  bool _isLoadingMore = false;
  BookSearchFilters _advancedFilters = BookSearchFilters.none;



  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    if (widget.initialQuery.trim().isNotEmpty) {
      _currentIndex = 1;
      _searchController.text = widget.initialQuery.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performSearch(widget.initialQuery.trim());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userName = context.read<AuthService>().currentUser ?? '';
      if (userName.isEmpty) return;
      _loadCachedReadList(userName);
      _subscribeToReadList(userName);
      _favoritesSub = _library.getFavoritesStream(userName).listen((items) {
        if (mounted) setState(() => _favorites = items);
      });
      _historySub = _library.getDownloadHistoryStream(userName).listen((items) {
        if (mounted) setState(() => _history = items);
      });
    });
  }

  @override
  void dispose() {
    _readlistSub?.cancel();
    _favoritesSub?.cancel();
    _historySub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedReadList(String userName) async {
    final cached = await _service.getCachedReadList(userName);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _readlist = cached;
        _splitLists();
      });
    }
  }

  void _subscribeToReadList(String userName) {
    _readlistSub = _service.getReadListStream(userName).listen((items) {
      if (mounted) {
        setState(() {
          _readlist = items;
          _splitLists();
        });
      }
    });
  }

  void _splitLists() {
    _toReadList = _readlist.where((item) => item.isToRead).toList();
    _readHistoryList = _readlist.where((item) => item.isRead).toList();
  }

  Future<void> _fetchHomeData() async {
    setState(() => _isLoadingHome = true);
    final feeds = await Future.wait([
      _catalog.mostPopular(limit: 12),
      _catalog.recentlyAdded(limit: 12),
    ]);
    if (!mounted) return;
    setState(() {
      _popular = feeds[0];
      _recent = feeds[1];
      _isLoadingHome = false;
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else if (_advancedFilters.isEmpty) {
        setState(() {
          _searchResults = [];
          _searchTotal = 0;
          _searchHasMore = false;
          _isSearching = false;
          _searchRan = false;
        });
      } else {
        _performSearch('');
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final page = await _catalog.searchPaged(
      query,
      filetype: _searchFiletype,
      language: _searchLanguage,
      sort: _searchSort,
      limit: _searchPageSize,
      filters: _advancedFilters,
    );
    if (mounted) {
      setState(() {
        _searchResults = page.results;
        _searchTotal = page.total;
        _searchHasMore = page.hasMore;
        _isSearching = false;
        _searchRan = true;
      });
    }
  }

  /// Z-Lib "Load more": appends the next Open Library page to the
  /// current result list.
  Future<void> _loadMoreSearch() async {
    if (_isLoadingMore || !_searchHasMore) return;
    setState(() => _isLoadingMore = true);
    final page = await _catalog.searchPaged(
      _searchController.text.trim(),
      filetype: _searchFiletype,
      language: _searchLanguage,
      sort: _searchSort,
      limit: _searchPageSize,
      offset: _searchResults.length,
      filters: _advancedFilters,
    );
    if (mounted) {
      setState(() {
        _searchResults = [..._searchResults, ...page.results];
        _searchTotal = page.total;
        _searchHasMore = page.hasMore;
        _isLoadingMore = false;
      });
    }
  }

  void _rerunSearchIfNeeded() {
    if (_searchController.text.trim().isNotEmpty ||
        _advancedFilters.isNotEmpty) {
      _performSearch(_searchController.text.trim());
    }
  }

  void _showBookDetails(BookItem item, [BookSearchResult? result]) {
    HapticFeedback.lightImpact();
    context.push(
      '/books/detail',
      extra: BookDetailArgs(item: item, result: result),
    );
  }

  void _showResultDetails(BookSearchResult result) {
    _showBookDetails(result.toBookItem(), result);
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _openFullDatabaseSearch() {
    _switchTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Widget _buildSearchFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cRose.withValues(alpha: 0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BookSort>(
                      value: _searchSort,
                      dropdownColor: _cCard,
                      style: AppTypography.outfitWhite.copyWith(
                        color: _cWhite,
                        fontSize: 11.5,
                      ),
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        color: _cMuted,
                        size: 16,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BookSort.relevant,
                          child: Text('Order: relevant'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.popular,
                          child: Text('Order: most popular'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.newest,
                          child: Text('Order: newest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.oldest,
                          child: Text('Order: oldest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.largest,
                          child: Text('Order: largest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.smallest,
                          child: Text('Order: smallest'),
                        ),
                        DropdownMenuItem(
                          value: BookSort.random,
                          child: Text('Order: random'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        HapticFeedback.selectionClick();
                        setState(() => _searchSort = value);
                        _rerunSearchIfNeeded();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                for (final ft in BookCatalogService.supportedFiletypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      icon: _filetypeIcon(ft),
                      label: ft.toUpperCase(),
                      color: _cDeepRose,
                      selected: _searchFiletype == ft,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _searchFiletype = _searchFiletype == ft ? null : ft;
                        });
                        _rerunSearchIfNeeded();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final lang in [
                  'All',
                  ...BookCatalogService.supportedLanguages.take(6),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      icon: Icons.language_rounded,
                      label: lang,
                      color: _cAmber,
                      selected:
                          (lang == 'All' && _searchLanguage == null) ||
                          _searchLanguage == lang,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _searchLanguage = lang == 'All' ? null : lang;
                        });
                        _rerunSearchIfNeeded();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _filetypeIcon(String ft) {
    switch (ft) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'epub':
        return Icons.menu_book_rounded;
      case 'mobi':
        return Icons.phone_iphone_rounded;
      case 'txt':
        return Icons.article_rounded;
      case 'html':
        return Icons.language_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  void _showRowDownload(BookSearchResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cRose.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Download',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: 24,
                color: _cWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Public-domain formats from ${result.sourceLabel}',
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in result.downloadUrls.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cDeepRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTypography.outfitBold.copyWith(
                          color: _cDeepRose,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${entry.key.toUpperCase()} file',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cWhite,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => downloadUrl(entry.value),
                      style: TextButton.styleFrom(
                        backgroundColor: _cDeepRose,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Download'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveResult(BookSearchResult result) async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save books'),
          backgroundColor: _cDeepRose,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await _service.saveToReadList(result.toBookItem(), 'to-read', userName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to your reading list'),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSearchEmptyState({
    String title = 'Type to discover magic',
    String subtitle =
        'Search any book, author, or subject across the full database.',
    IconData icon = Icons.travel_explore_rounded,
  }) {
    return EverglowEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }
}
