part of 'books_screen.dart';

abstract class _BooksScreenStateBase extends State<BooksScreen> {
  final OpenLibraryService _service = OpenLibraryService();
  final BookCatalogService _catalog = BookCatalogService();
  int _currentIndex = 0;

  StreamSubscription<List<BookItem>>? _readlistSub;
  List<BookItem> _readlist = [];
  List<BookItem> _toReadList = [];
  List<BookItem> _readHistoryList = [];

  List<BookItem> _trendingCarousel = [];
  List<BookItem> _trendingRankings = [];
  final Map<String, List<BookItem>> _subjectLists = {};
  bool _isLoadingHome = true;
  final PageController _carouselController = PageController(
    viewportFraction: 0.88,
  );
  int _carouselPage = 0;
  Timer? _carouselTimer;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<BookSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  BookSort _searchSort = BookSort.relevant;
  String? _searchFiletype;
  String? _searchLanguage;
  bool _searchRan = false;

  static final List<Map<String, dynamic>> _featuredSubjects = [
    {
      'name': 'Romance',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFE91E63),
    },
    {
      'name': 'Mystery',
      'icon': Icons.search_rounded,
      'color': const Color(0xFF7B1FA2),
    },
    {
      'name': 'Science Fiction',
      'icon': Icons.rocket_launch_rounded,
      'color': const Color(0xFF00BCD4),
    },
    {
      'name': 'Fantasy',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFF3949AB),
    },
    {
      'name': 'Classics',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFFE8C97A),
    },
    {
      'name': 'Adventure',
      'icon': Icons.explore_rounded,
      'color': const Color(0xFFEF6C00),
    },
    {
      'name': 'Horror',
      'icon': Icons.brightness_3_rounded,
      'color': const Color(0xFF1A1A2E),
    },
    {
      'name': 'Poetry',
      'icon': Icons.auto_awesome_motion_outlined,
      'color': const Color(0xFFD4B5D6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userName = context.read<AuthService>().currentUser ?? '';
      if (userName.isEmpty) return;
      _loadCachedReadList(userName);
      _subscribeToReadList(userName);
    });
  }

  @override
  void dispose() {
    _readlistSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _carouselController.dispose();
    _carouselTimer?.cancel();
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

    final trending = await _service.fetchTrending();
    if (!mounted) return;
    setState(() {
      _trendingRankings = trending;
      _trendingCarousel = trending.take(5).toList();
      _isLoadingHome = false;
    });
    _startCarouselAutoPlay();
    _fetchSubjectLists();
  }

  Future<void> _fetchSubjectLists() async {
    for (final subject in _featuredSubjects) {
      final name = subject['name'] as String;
      final items = await _service.discoverBySubject(name, limit: 12);
      if (mounted && items.isNotEmpty) {
        setState(() {
          _subjectLists[name] = items;
        });
      }
    }
  }

  static const Duration _carouselHoldDuration = Duration(seconds: 12);

  void _onCarouselPageChanged(int index) {
    setState(() => _carouselPage = index);
    _restartCarouselAutoPlay();
  }

  void _startCarouselAutoPlay() => _restartCarouselAutoPlay();

  void _restartCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer(_carouselHoldDuration, () {
      if (!mounted) return;
      if (_trendingCarousel.isEmpty || !_carouselController.hasClients) return;
      final nextPage = (_carouselPage + 1) % _trendingCarousel.length;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchRan = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await _catalog.search(
      query,
      filetype: _searchFiletype,
      language: _searchLanguage,
      sort: _searchSort,
      limit: 30,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchRan = true;
      });
    }
  }

  void _showBookDetails(BookItem item) {
    HapticFeedback.lightImpact();
    context.push('/books/detail', extra: BookDetailArgs(item: item));
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
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
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
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
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
                        if (_searchController.text.trim().isNotEmpty) {
                          _performSearch(_searchController.text.trim());
                        }
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

  void _shareResult(BookSearchResult result) async {
    HapticFeedback.selectionClick();
    String url = '';
    if (result.gutenbergId > 0) {
      url = 'https://www.gutenberg.org/ebooks/${result.gutenbergId}';
    } else if (result.iaId.isNotEmpty) {
      url = 'https://archive.org/details/${result.iaId}';
    } else if (result.workKey.isNotEmpty) {
      url = 'https://openlibrary.org${result.workKey}';
    }
    await Clipboard.setData(ClipboardData(text: '$url\n${result.title}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied'),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
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
    return ShelfEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: _cDeepRose,
    );
  }
}
