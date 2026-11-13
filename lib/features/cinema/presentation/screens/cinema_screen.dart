import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/cinema_home_cache.dart';
import '../../data/services/cinema_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/optimistic_action.dart';
import '../widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../widgets/cinema_playback_sheet.dart';
import 'package:go_router/go_router.dart';
import '../widgets/netflix/netflix_colors.dart';
import '../widgets/netflix/netflix_nav_bar.dart';

import '../widgets/tabs/cinema_home_tab.dart' show CinemaHomeTab;
import '../widgets/tabs/cinema_search_tab.dart' show CinemaSearchTab;
import '../widgets/tabs/cinema_browse_tab.dart' show CinemaBrowseTab;
import '../widgets/tabs/cinema_library_tab.dart' show CinemaLibraryTab;
import '../widgets/tabs/cinema_downloads_tab.dart' show CinemaDownloadsTab;
import '../../../watch_party/presentation/widgets/cinema_watch_together_tab.dart';
import '../../../../shared/widgets/everglow/lazy_indexed_stack.dart';
import '../../../../shared/widgets/shelf/media_section_menu.dart';
import '../../../../shared/widgets/shelf/tv_media_nav_header.dart';
import '../../../../core/system/tv_mode.dart';

// ─────────────────────────────────────────────────────────────────────
// Cinema Color Tokens
// ─────────────────────────────────────────────────────────────────────

class CinemaScreen extends StatefulWidget {
  final TMDBService? service;
  final int initialTab;
  final String? initialBrowseOption;

  const CinemaScreen({
    super.key,
    this.initialTab = 0,
    this.initialBrowseOption,
    this.service,
  });

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  late final TMDBService _tmdbService = widget.service ?? TMDBService();
  int _currentIndex = 0;

  /// Bumped every time a nav link targets the Browse tab so it rebuilds
  /// with the requested filter even when it is already mounted.
  int _browseSeed = 0;
  String? _pendingBrowseOption;

  bool _desktopScrolled = false;

  StreamSubscription<List<MediaItem>>? _watchlistSubscription;
  late final AuthService _auth;
  String _listUser = '';
  int _listRevision = 0;

  final OptimisticSet<String> _optimisticWatchlist = OptimisticSet<String>();
  final Map<String, MediaItem> _optimisticAddedItems = {};

  List<MediaItem> _watchlist = [];
  List<MediaItem> _watchingList = [];

  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
  List<MediaItem> _topTenToday = [];
  List<MediaItem> _popularTVShows = [];
  List<MediaItem> _newlyReleased = [];

  static const _discoveryShelves = [
    (title: 'Top-Rated Movies', type: 'movie', genre: null, language: null),
    (title: 'Top-Rated Series', type: 'tv', genre: null, language: null),
    (title: 'Action & Adventure', type: 'movie', genre: 28, language: null),
    (title: 'Need a Laugh?', type: 'movie', genre: 35, language: null),
    (title: 'Romance', type: 'movie', genre: 10749, language: null),
    (
      title: 'Edge-of-Your-Seat Thrillers',
      type: 'movie',
      genre: 53,
      language: null,
    ),
    (title: 'Sci-Fi Escapes', type: 'movie', genre: 878, language: null),
    (title: 'Korean Dramas', type: 'tv', genre: 18, language: 'ko'),
  ];
  final Map<String, List<MediaItem>> _discoveryRows = {
    for (final shelf in _discoveryShelves) shelf.title: [],
  };

  bool _isLoadingHome = true;
  int _homeRequest = 0;

  /// How long saved Home rows are shown before Cinema asks TMDB again.
  /// Matches the proxy's own 10-minute catalogue cache.
  static const _homeFreshFor = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _pendingBrowseOption = widget.initialBrowseOption;
    if (_pendingBrowseOption != null) {
      _currentIndex = 2;
      _browseSeed = 1;
    } else {
      _currentIndex = widget.initialTab.clamp(0, 5);
    }
    // Paint the last good rows now when this session has them; otherwise read
    // the saved copy.
    final warm = CinemaHomeCache.session;
    if (warm != null) {
      _applyCachedRows(warm);
    } else {
      unawaited(_restoreHomeCache());
    }
    if (_currentIndex == 0) {
      // Recent rows are already on screen. Asking TMDB again would spend
      // twelve requests to redraw what she is looking at, so leave that to
      // the pull-to-refresh instead.
      if (CinemaHomeCache.isFresh(_homeFreshFor)) {
        _isLoadingHome = false;
      } else {
        _fetchHomeData();
      }
    }
    _auth = context.read<AuthService>();
    _auth.addListener(_syncProfile);
    _syncProfile();
  }

  void _syncProfile() {
    final user = _auth.currentUser ?? '';
    unawaited(CinemaPreferences.instance.setUser(user));
    if (user == _listUser) return;
    _listUser = user;
    ++_listRevision;
    _watchlistSubscription?.cancel();
    _watchlist = [];
    _watchingList = [];
    _optimisticWatchlist.clearAll();
    _optimisticAddedItems.clear();
    if (user.isNotEmpty) {
      _subscribeToWatchList(user);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_syncProfile);
    _watchlistSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToWatchList(String userName) {
    _watchlistSubscription = _tmdbService.getWatchListStream(userName).listen((
      items,
    ) async {
      if (!mounted || userName != _listUser) return;
      final revision = ++_listRevision;
      _optimisticWatchlist.reconcile(items.map((e) => e.catalogKey));
      _optimisticAddedItems.removeWhere(
        (id, _) => !_optimisticWatchlist.isAdded(id),
      );

      final effective = items
          .where((m) => !_optimisticWatchlist.isRemoved(m.catalogKey))
          .toList();
      for (final id in _optimisticWatchlist.added) {
        if (!effective.any((m) => m.catalogKey == id) &&
            _optimisticAddedItems.containsKey(id)) {
          effective.add(_optimisticAddedItems[id]!);
        }
      }

      setState(() {
        _watchlist = effective;
        _splitWatchlists();
      });
      // Poster healing runs after paint so the list shows instantly; each
      // pass only touches items still missing art.
      var refreshed = await _tmdbService.backfillMissingPosters(effective);
      refreshed = await _tmdbService.refreshAnimePosters(refreshed);
      if (!mounted || userName != _listUser || revision != _listRevision) {
        return;
      }
      setState(() {
        _watchlist = refreshed;
        _splitWatchlists();
      });
    });
  }

  void _splitWatchlists() {
    // Cinema's rails own every movie (live-action or anime) plus non-anime
    // TV — see MediaItem.isCinemaItem. Anime series live in the anime rail.
    _watchingList = _watchlist.watchingCinema
      ..sort(
        (a, b) => (b.progressUpdatedAt ?? b.addedAt).compareTo(
          a.progressUpdatedAt ?? a.addedAt,
        ),
      );
  }

  /// Fills Home rows from [rows] only where the network has not filled them,
  /// so a late storage read never overwrites fresher data.
  void _applyCachedRows(Map<String, List<MediaItem>> rows) {
    List<MediaItem> pick(String key, List<MediaItem> live) =>
        live.isNotEmpty ? live : (rows[key] ?? const []);
    _trendingGlobal = pick('trendingGlobal', _trendingGlobal);
    if (_trendingCarousel.isEmpty) {
      _trendingCarousel = _trendingGlobal.take(5).toList();
    }
    _topTenToday = pick('topTenToday', _topTenToday);
    _popularTVShows = pick('popularTVShows', _popularTVShows);
    _newlyReleased = pick('newlyReleased', _newlyReleased);
    for (final shelf in _discoveryShelves) {
      _discoveryRows[shelf.title] = pick(
        shelf.title,
        _discoveryRows[shelf.title] ?? const [],
      );
    }
  }

  Future<void> _restoreHomeCache() async {
    final rows = await CinemaHomeCache.read();
    if (!mounted || rows == null) return;
    setState(() => _applyCachedRows(rows));
  }

  void _saveHomeCache() {
    unawaited(
      CinemaHomeCache.save({
        'trendingGlobal': _trendingGlobal,
        'topTenToday': _topTenToday,
        'popularTVShows': _popularTVShows,
        'newlyReleased': _newlyReleased,
        for (final shelf in _discoveryShelves)
          shelf.title: _discoveryRows[shelf.title] ?? const [],
      }),
    );
  }

  Future<void> _fetchHomeData() async {
    final request = ++_homeRequest;
    setState(() => _isLoadingHome = true);
    final year = DateTime.now().year;

    // Above-the-fold content (hero carousel + top 10 today) loads first so
    // the screen becomes interactive immediately without waiting on off-screen rails.
    final primaryFutures = [
      _loadRow(
        _tmdbService.fetchTrending(region: 'all', timeWindow: 'week'),
        request,
        (items) {
          _trendingGlobal = items;
          _trendingCarousel = items.take(5).toList();
        },
      ),
      _loadRow(
        _tmdbService.fetchTrendingByCountry(countryCode: 'PH'),
        request,
        (items) => _topTenToday = items,
      ),
      _loadRow(
        _tmdbService.fetchPopularTVShows(),
        request,
        (items) => _popularTVShows = items,
      ),
      _loadRow(
        _tmdbService.fetchUpcoming(region: 'PH'),
        request,
        (items) => _newlyReleased = items.where((m) {
          final released = int.tryParse(m.year);
          return released == null || released >= year - 1;
        }).toList(),
      ),
    ];

    await Future.wait(primaryFutures);
    _saveHomeCache();
    if (mounted && request == _homeRequest) {
      setState(() => _isLoadingHome = false);
    }

    // Off-screen discovery shelves load progressively in the background.
    final discoveryFutures = [
      for (final shelf in _discoveryShelves)
        _loadRow(
          _tmdbService.discoverMedia(
            mediaType: shelf.type,
            sortBy: shelf.genre == null
                ? 'vote_average.desc'
                : 'popularity.desc',
            withGenres: shelf.genre == null ? null : [shelf.genre!],
            withOriginalLanguage: shelf.language,
            voteCountGte: shelf.genre == null ? 1000 : 100,
          ),
          request,
          (items) => _discoveryRows[shelf.title] = items,
        ),
    ];
    await Future.wait(discoveryFutures);
    _saveHomeCache();
  }

  Future<void> _loadRow(
    Future<List<MediaItem>> future,
    int request,
    void Function(List<MediaItem>) apply,
  ) async {
    try {
      final items = await future;
      if (!mounted || request != _homeRequest) return;
      // Home discovery excludes anime films too; saved history stays untouched.
      final visible = items.where((m) => !m.isAnime).toList();
      // A failed fetch comes back empty. Keep what is already on screen (the
      // saved rows on a repeat open) instead of blanking the row.
      if (visible.isEmpty) return;
      setState(() => apply(visible));
    } catch (e, st) {
      Logger.e('Cinema: home rail fetch failed', error: e, stackTrace: st);
    }
  }

  void _showMediaDetails(MediaItem item) {
    var drawerItem = item;
    for (final saved in _watchlist) {
      if (saved.catalogKey == item.catalogKey) {
        drawerItem = item.copyWith(
          status: saved.status,
          currentSeason: saved.currentSeason,
          currentEpisode: saved.currentEpisode,
          currentTimestamp: saved.currentTimestamp,
          durationSeconds: saved.durationSeconds,
          progressUpdatedAt: saved.progressUpdatedAt,
        );
        break;
      }
    }
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, _, _) => EpisodeDrawer(
        item: drawerItem,
        cinemaVariant: true,
        topTenRank: topTenRankFor(_topTenToday, item),
        topTenItems: _topTenToday,
      ),
      transitionBuilder: (context, animation, _, child) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    if (index == 0 && _homeRequest == 0) _fetchHomeData();
    setState(() {
      _currentIndex = index;
    });
  }

  /// Opens the Browse tab seeded with [optionId] (used by nav links).
  void _openBrowse(String optionId) {
    HapticFeedback.selectionClick();
    setState(() {
      _pendingBrowseOption = optionId;
      _browseSeed++;
      _currentIndex = 2;
    });
  }

  /// Netflix-style Play from the billboard: movies jump straight into the
  /// player; series open the drawer so the right episode can be picked.
  void _playNow(MediaItem item) {
    if (item.mediaType == 'movie') {
      context.push(
        '/cinema/video/${item.tmdbId}?type=movie'
        '&title=${Uri.encodeComponent(item.title)}&anime=false',
      );
      return;
    }
    _showMediaDetails(item);
  }

  void _playMedia(MediaItem item) {
    if ((item.currentTimestamp ?? 0) > 0 || (item.currentEpisode ?? 0) > 0) {
      _manageProgress(item);
    } else {
      _launchMedia(item);
    }
  }

  Future<void> _manageProgress(MediaItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NetflixColors.surface,
      isScrollControlled: true,
      builder: (_) => CinemaPlaybackSheet(item: item),
    );
    if (!mounted) return;
    switch (action) {
      case 'resume':
        _launchMedia(item);
      case 'restart':
        _restartMedia(item);
      case 'episodes':
        _showMediaDetails(item);
      case 'remove':
        await _removeProgress(item);
      case 'finished':
        final username = _auth.currentUser;
        if (username == null) return;
        try {
          await _tmdbService.watchlist.updateProgress(
            item,
            username,
            season: item.currentSeason,
            episode: item.currentEpisode,
            timestamp: item.currentTimestamp,
            durationSeconds: item.durationSeconds,
            status: 'watched-self',
            failOnError: true,
          );
          if (!mounted || _auth.currentUser != username) return;
          setState(() {
            _watchlist = _watchlist
                .map(
                  (saved) => saved.catalogKey == item.catalogKey
                      ? saved.copyWith(status: 'watched-self')
                      : saved,
                )
                .toList();
            _splitWatchlists();
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Marked as finished.')));
        } catch (e) {
          Logger.e('Cinema: could not mark finished', error: e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save. Please try again.'),
              ),
            );
          }
        }
    }
  }

  void _launchMedia(MediaItem item) {
    // Omit unknown position so cloud + local memory can restore the saved
    // spot. Explicit start=0 is reserved for Restart.
    if (item.mediaType == 'movie') {
      final resume = item.resumeSeconds;
      context.push(
        '/cinema/video/${item.tmdbId}?type=movie'
        '&title=${Uri.encodeComponent(item.title)}&anime=false'
        '${resume != null ? '&start=$resume' : ''}',
      );
      return;
    }
    final season = item.currentSeason;
    final episode = item.currentEpisode;
    final resume = item.resumeSeconds;
    final watchedParam = item.isWatched ? '&watched=true' : '';
    final duration = item.durationSeconds ?? 0;
    final completedParam =
        season != null &&
            season > 0 &&
            episode != null &&
            episode > 0 &&
            item.currentSeason == season &&
            item.currentEpisode == episode &&
            duration > 0 &&
            (item.currentTimestamp ?? 0) / duration >= 0.95
        ? '&completed=true'
        : '';
    context.push(
      '/cinema/video/${item.tmdbId}?type=tv'
      '&title=${Uri.encodeComponent(item.title)}&anime=false'
      '${season != null && season > 0 ? '&season=$season' : ''}'
      '${episode != null && episode > 0 ? '&episode=$episode' : ''}'
      '${resume != null ? '&start=$resume' : ''}$watchedParam$completedParam',
    );
  }

  void _restartMedia(MediaItem item) {
    final season = item.currentSeason ?? 1;
    final episode = item.currentEpisode ?? 1;
    final watchedParam = item.isWatched ? '&watched=true' : '';
    final duration = item.durationSeconds ?? 0;
    final completedParam =
        item.currentEpisode == episode &&
            item.currentSeason == season &&
            duration > 0 &&
            (item.currentTimestamp ?? 0) / duration >= 0.95
        ? '&completed=true'
        : '';
    context.push(
      '/cinema/video/${item.tmdbId}?type=${item.mediaType}'
      '&title=${Uri.encodeComponent(item.title)}&anime=false'
      '${item.mediaType == 'tv' ? '&season=$season&episode=$episode' : ''}'
      '&start=0$watchedParam$completedParam',
    );
  }

  Future<void> _toggleListItem(MediaItem item, bool add) async {
    final userName = _auth.currentUser ?? '';
    if (userName.isEmpty) return;
    final revision = _listRevision;

    HapticFeedback.selectionClick();

    await OptimisticAction.run(
      apply: () {
        if (!mounted ||
            _auth.currentUser != userName ||
            revision != _listRevision) {
          return;
        }
        setState(() {
          if (add) {
            _optimisticWatchlist.markAdded(item.catalogKey);
            final optimisticItem = item.copyWith(
              status: 'to-watch',
              userName: userName,
            );
            _optimisticAddedItems[item.catalogKey] = optimisticItem;
            if (!_watchlist.any((w) => w.catalogKey == item.catalogKey)) {
              _watchlist = [..._watchlist, optimisticItem];
            }
          } else {
            _optimisticWatchlist.markRemoved(item.catalogKey);
            _optimisticAddedItems.remove(item.catalogKey);
            _watchlist = _watchlist
                .where((w) => w.catalogKey != item.catalogKey)
                .toList();
          }
          _splitWatchlists();
        });
      },
      action: () => _tmdbService.setListMembership(item, userName, add: add),
      rollback: () {
        if (!mounted ||
            _auth.currentUser != userName ||
            revision != _listRevision) {
          return;
        }
        setState(() {
          if (add) {
            _optimisticWatchlist.rollbackAdd(item.catalogKey);
            _optimisticAddedItems.remove(item.catalogKey);
            _watchlist = _watchlist
                .where((w) => w.catalogKey != item.catalogKey)
                .toList();
          } else {
            _optimisticWatchlist.rollbackRemove(item.catalogKey);
            if (!_watchlist.any((w) => w.catalogKey == item.catalogKey)) {
              _watchlist = [..._watchlist, item];
            }
          }
          _splitWatchlists();
        });
      },
      onError: (e, _) {
        debugPrint('[Cinema] Failed to update list membership: $e');
        if (mounted &&
            _auth.currentUser == userName &&
            revision == _listRevision) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Could not update "${item.title}" in your list. Reverted.',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
    );
  }

  Future<void> _removeProgress(MediaItem item) async {
    final user = _auth.currentUser ?? '';
    if (user.isEmpty) return;
    HapticFeedback.lightImpact();
    await OptimisticAction.run<void>(
      apply: () {
        if (!mounted || _auth.currentUser != user) return;
        setState(() {
          _watchlist = _watchlist
              .map(
                (m) => m.catalogKey == item.catalogKey
                    ? m.copyWith(status: 'to-watch', clearProgress: true)
                    : m,
              )
              .toList();
          _splitWatchlists();
        });
      },
      action: () => _tmdbService.clearWatchProgress(item, user),
      rollback: () {
        if (!mounted || _auth.currentUser != user) return;
        setState(() {
          _watchlist = _watchlist
              .map((m) => m.catalogKey == item.catalogKey ? item : m)
              .toList();
          _splitWatchlists();
        });
      },
      onSuccess: (_) {
        if (!mounted || _auth.currentUser != user) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Removed "${item.title}" from Continue Watching'),
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => unawaited(_undoProgressRemoval(item, user)),
              ),
            ),
          );
      },
      onError: (e, st) {
        Logger.e('Cinema: could not remove progress', error: e, stackTrace: st);
        if (mounted && _auth.currentUser == user) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not remove this title. Please try again.'),
            ),
          );
        }
      },
    );
  }

  Future<void> _undoProgressRemoval(MediaItem item, String user) async {
    if (!mounted || _auth.currentUser != user) return;
    try {
      final restored = await _tmdbService.watchlist.restoreWatchProgress(
        item,
        user,
      );
      if (!mounted || _auth.currentUser != user) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Restored to Continue Watching'
                : 'Kept your newer viewing progress',
          ),
        ),
      );
    } catch (e, st) {
      Logger.e('Cinema: undo failed', error: e, stackTrace: st);
      if (mounted && _auth.currentUser == user) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not restore progress. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _rateItem(MediaItem item, double? rating) async {
    final userName = _auth.currentUser ?? '';
    if (userName.isEmpty) return;
    HapticFeedback.selectionClick();

    final previousWatchlist = List<MediaItem>.of(_watchlist);
    final revision = _listRevision;

    await OptimisticAction.run(
      apply: () {
        if (!mounted ||
            _auth.currentUser != userName ||
            revision != _listRevision) {
          return;
        }
        setState(() {
          final index = _watchlist.indexWhere(
            (w) => w.catalogKey == item.catalogKey,
          );
          if (index >= 0) {
            final copy = List<MediaItem>.of(_watchlist);
            copy[index] = _watchlist[index].copyWith(userRating: rating);
            _watchlist = copy;
          } else {
            _watchlist = [
              ..._watchlist,
              item.copyWith(
                status: 'to-watch',
                userName: userName,
                userRating: rating,
              ),
            ];
          }
          _splitWatchlists();
        });
      },
      action: () => _tmdbService.setUserRating(item, userName, rating: rating),
      rollback: () {
        if (!mounted ||
            _auth.currentUser != userName ||
            revision != _listRevision) {
          return;
        }
        setState(() {
          _watchlist = previousWatchlist;
          _splitWatchlists();
        });
      },
      onError: (e, _) {
        debugPrint('[Cinema] Failed to save title rating: $e');
      },
    );
  }

  void _onNavSelect(int tab, String? browseOptionId) {
    if (browseOptionId != null) {
      _openBrowse(browseOptionId);
      return;
    }
    _switchTab(tab);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 12;
    if (scrolled != _desktopScrolled) {
      setState(() => _desktopScrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TvMode.isTvMode,
      builder: (context, isTv, _) => _buildForTvMode(context, isTv),
    );
  }

  Widget _buildForTvMode(BuildContext context, bool isTv) {
    final isDesktop = AppBreakpoint.isDesktop(context) || isTv;
    final isCoupleUser = context.select<AuthService, bool>(
      (a) => a.isCoupleUser,
    );
    final isCinemaOnlyUser = context.select<AuthService, bool>(
      (a) => a.isCinemaOnlyUser,
    );

    const navLinks = [
      NetflixNavLink('Home', 0),
      NetflixNavLink('Popular', 2, 'collection-new'),
      NetflixNavLink('My List', 3),
      NetflixNavLink('Downloads', 5),
      NetflixNavLink('Search', 1),
    ];
    final userName = context.select<AuthService, String>(
      (a) => a.currentUser ?? '',
    );

    // Main cinema content. The desktop top bar overlays it so the hero
    // can remain full bleed, just like the streaming-service pattern.
    Widget buildCinemaContent() {
      return NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          children: [
            const ColoredBox(color: NetflixColors.background),
            LazyIndexedStack(
              index: _currentIndex,
              children: [
                CinemaHomeTab(
                  isLoadingHome: _isLoadingHome,
                  trendingCarousel: _trendingCarousel,
                  popularTVShows: _popularTVShows,
                  newlyReleased: _newlyReleased,
                  discoveryRows: _discoveryRows,
                  watchingList: _watchingList,
                  savedList: _watchlist.cinemaItems.toWatch,
                  onRestart: _restartMedia,
                  trendingGlobal: _trendingGlobal,
                  topTenToday: _topTenToday,
                  onRefresh: _fetchHomeData,
                  onMediaTap: _showMediaDetails,
                  onPlay: _playNow,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) => _watchlist.any(
                    (saved) => saved.catalogKey == item.catalogKey,
                  ),
                  onRemoveProgress: _removeProgress,
                  onSwitchTab: _switchTab,
                ),
                CinemaSearchTab(
                  trendingGlobal: _trendingGlobal,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) => _watchlist.any(
                    (saved) => saved.catalogKey == item.catalogKey,
                  ),
                  onSwitchTab: _switchTab,
                ),
                CinemaBrowseTab(
                  key: ValueKey('browse-$_browseSeed'),
                  initialOptionId: _pendingBrowseOption,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) => _watchlist.any(
                    (saved) => saved.catalogKey == item.catalogKey,
                  ),
                ),
                CinemaLibraryTab(
                  watchlist: _watchlist,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  onRemoveProgress: _removeProgress,
                  onSwitchTab: _switchTab,
                ),
                // The lazy stack mounts every tab on first visit, so the
                // room stream here costs nothing until Claire opens the tab.
                CinemaWatchTogetherTab(
                  watchlist: _watchlist,
                  onMediaTap: _showMediaDetails,
                  onSwitchTab: _switchTab,
                ),
                CinemaDownloadsTab(
                  onPlayMedia: _playMedia,
                  onBrowseCinema: () => _switchTab(0),
                ),
              ],
            ),
            // Floating back button (mobile/tablet): couple users return to
            // the dashboard; cinema-only profiles have no dashboard, so
            // they get a logout action instead (their only mobile exit,
            // mirroring the desktop profile menu).
            if (!isDesktop && isCinemaOnlyUser && !TvMode.isTvMode.value)
              const Positioned(
                top: 0,
                right: 12,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Material(
                      color: NetflixColors.surface,
                      shape: CircleBorder(),
                      child: MediaSectionMenu(currentRoute: '/cinema'),
                    ),
                  ),
                ),
              ),
            if (!isDesktop && !TvMode.isTvMode.value)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 10),
                    child: Tooltip(
                      message: isCoupleUser ? 'Dashboard' : 'Logout',
                      child: Material(
                        color: NetflixColors.surface,
                        shape: const CircleBorder(
                          side: BorderSide(color: NetflixColors.hairline),
                        ),
                        elevation: 8,
                        child: InkWell(
                          onTap: isCoupleUser
                              ? () {
                                  HapticFeedback.selectionClick();
                                  GoRouter.of(context).go('/dashboard');
                                }
                              : () async {
                                  HapticFeedback.selectionClick();
                                  final router = GoRouter.of(context);
                                  try {
                                    await context.read<AuthService>().logout();
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context
                                                  .read<AuthService>()
                                                  .lastAuthError ??
                                              'Could not log out safely. Try again.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!mounted) return;
                                  router.go('/');
                                },
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              isCoupleUser
                                  ? Icons.arrow_back_rounded
                                  : Icons.logout_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ── Desktop: transparent-to-solid catalog top bar ─────────────
    if (isDesktop) {
      return Scaffold(
        backgroundColor: NetflixColors.background,
        extendBody: true,
        body: Stack(
          children: [
            buildCinemaContent(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TvMediaNavHeader(currentRoute: '/cinema'),
                  NetflixCinemaTopBar(
                    currentIndex: _currentIndex,
                    scrolled: _desktopScrolled,
                    onSelect: _onNavSelect,
                    onAnimeTap: () => GoRouter.of(context).go('/anime'),
                    onDashboardTap: isCoupleUser
                        ? () => GoRouter.of(context).go('/dashboard')
                        : null,
                    onLogout: () async {
                      final router = GoRouter.of(context);
                      try {
                        await context.read<AuthService>().logout();
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.read<AuthService>().lastAuthError ??
                                  'Could not log out safely. Try again.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (!mounted) return;
                      router.go('/');
                    },
                    userName: userName,
                    showAnime: isCinemaOnlyUser,
                    links: navLinks,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile / Tablet: content + bottom nav ───────────────────────
    return Scaffold(
      extendBody: true,
      backgroundColor: NetflixColors.background,
      body: Column(
        children: [
          const TvMediaNavHeader(currentRoute: '/cinema'),
          Expanded(child: buildCinemaContent()),
        ],
      ),
      bottomNavigationBar: NetflixNavBar(
        scrolled: false,
        currentIndex: _currentIndex,
        links: navLinks,
        // Cinema-only profiles get Anime instead of Together here — it is
        // their only ride to `/anime` on mobile (no dashboard, and the
        // floating button is their logout).
        mobileItems: cinemaMobileNavItems(
          isCinemaOnlyUser: isCinemaOnlyUser,
        ),
        onSelect: _onNavSelect,
        onAnimeTap: () => GoRouter.of(context).go('/anime'),
      ),
    );
  }
}
