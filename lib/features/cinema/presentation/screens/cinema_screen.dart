import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/cinema_preferences.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/optimistic_action.dart';
import '../widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';
import '../widgets/netflix/netflix_colors.dart';
import '../widgets/netflix/netflix_nav_bar.dart';

import '../widgets/tabs/cinema_home_tab.dart' show CinemaHomeTab;
import '../widgets/tabs/cinema_search_tab.dart' show CinemaSearchTab;
import '../widgets/tabs/cinema_browse_tab.dart' show CinemaBrowseTab;
import '../widgets/tabs/cinema_library_tab.dart' show CinemaLibraryTab;
import '../../../watch_party/presentation/widgets/cinema_watch_together_tab.dart';
import '../../../../shared/widgets/everglow/lazy_indexed_stack.dart';

// ─────────────────────────────────────────────────────────────────────
// Cinema Color Tokens
// ─────────────────────────────────────────────────────────────────────

class CinemaScreen extends StatefulWidget {
  final int initialTab;
  final String? initialBrowseOption;

  const CinemaScreen({
    super.key,
    this.initialTab = 0,
    this.initialBrowseOption,
  });

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final TMDBService _tmdbService = TMDBService();
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

  final OptimisticSet<int> _optimisticWatchlist = OptimisticSet<int>();
  final Map<int, MediaItem> _optimisticAddedItems = {};

  List<MediaItem> _watchlist = [];
  List<MediaItem> _watchingList = [];

  List<MediaItem> _trendingCarousel = [];
  List<MediaItem> _trendingGlobal = [];
  List<MediaItem> _topTenToday = [];
  List<MediaItem> _popularTVShows = [];
  List<MediaItem> _newlyReleased = [];

  bool _isLoadingHome = true;
  int _homeRequest = 0;

  @override
  void initState() {
    super.initState();
    _pendingBrowseOption = widget.initialBrowseOption;
    if (_pendingBrowseOption != null) {
      _currentIndex = 2;
      _browseSeed = 1;
    } else {
      _currentIndex = widget.initialTab.clamp(0, 4);
    }
    _fetchHomeData();
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
      _loadCachedWatchList(user);
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

  Future<void> _loadCachedWatchList(String userName) async {
    final revision = _listRevision;
    final cached = await _tmdbService.getCachedWatchList(userName);
    if (cached.isNotEmpty &&
        mounted &&
        userName == _listUser &&
        revision == _listRevision) {
      setState(() {
        _watchlist = cached;
        _splitWatchlists();
      });
    }
  }

  void _subscribeToWatchList(String userName) {
    _watchlistSubscription = _tmdbService.getWatchListStream(userName).listen((
      items,
    ) async {
      if (!mounted || userName != _listUser) return;
      final revision = ++_listRevision;
      _optimisticWatchlist.reconcile(items.map((e) => e.tmdbId));
      _optimisticAddedItems.removeWhere(
        (id, _) => !_optimisticWatchlist.isAdded(id),
      );

      final effective = items
          .where((m) => !_optimisticWatchlist.isRemoved(m.tmdbId))
          .toList();
      for (final id in _optimisticWatchlist.added) {
        if (!effective.any((m) => m.tmdbId == id) &&
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

  Future<void> _fetchHomeData() async {
    final request = ++_homeRequest;
    setState(() => _isLoadingHome = true);
    // Four small discovery feeds; the full catalogue is fetched in Browse.
    final year = DateTime.now().year;
    await Future.wait([
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
    ]);
    if (mounted && request == _homeRequest) {
      setState(() => _isLoadingHome = false);
    }
  }

  Future<void> _loadRow(
    Future<List<MediaItem>> future,
    int request,
    void Function(List<MediaItem>) apply,
  ) async {
    try {
      final items = await future;
      if (!mounted || request != _homeRequest) return;
      setState(() => apply(items.where((m) => m.isCinemaItem).toList()));
    } catch (e, st) {
      Logger.e('Cinema: home rail fetch failed', error: e, stackTrace: st);
    }
  }

  void _showMediaDetails(MediaItem item) {
    var drawerItem = item;
    for (final saved in _watchlist) {
      if (saved.tmdbId == item.tmdbId &&
          saved.mediaType == item.mediaType &&
          saved.isAnime == item.isAnime) {
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
      pageBuilder: (context, _, _) =>
          EpisodeDrawer(item: drawerItem, cinemaVariant: true),
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
            _optimisticWatchlist.markAdded(item.tmdbId);
            final optimisticItem = item.copyWith(
              status: 'to-watch',
              userName: userName,
            );
            _optimisticAddedItems[item.tmdbId] = optimisticItem;
            if (!_watchlist.any((w) => w.tmdbId == item.tmdbId)) {
              _watchlist = [..._watchlist, optimisticItem];
            }
          } else {
            _optimisticWatchlist.markRemoved(item.tmdbId);
            _optimisticAddedItems.remove(item.tmdbId);
            _watchlist = _watchlist
                .where((w) => w.tmdbId != item.tmdbId)
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
            _optimisticWatchlist.rollbackAdd(item.tmdbId);
            _optimisticAddedItems.remove(item.tmdbId);
            _watchlist = _watchlist
                .where((w) => w.tmdbId != item.tmdbId)
                .toList();
          } else {
            _optimisticWatchlist.rollbackRemove(item.tmdbId);
            if (!_watchlist.any((w) => w.tmdbId == item.tmdbId)) {
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
                (m) => m.tmdbId == item.tmdbId
                    ? m.copyWith(status: 'to-watch', clearProgress: true)
                    : m,
              )
              .toList();
          _splitWatchlists();
        });
      },
      action: () => _tmdbService.clearWatchProgress(item.tmdbId, user),
      rollback: () {
        if (!mounted || _auth.currentUser != user) return;
        setState(() {
          _watchlist = _watchlist
              .map((m) => m.tmdbId == item.tmdbId ? item : m)
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
          final index = _watchlist.indexWhere((w) => w.tmdbId == item.tmdbId);
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
    final isDesktop = AppBreakpoint.isDesktop(context);
    final isCoupleUser = context.select<AuthService, bool>(
      (a) => a.isCoupleUser,
    );
    final isCinemaOnlyUser = context.select<AuthService, bool>(
      (a) => a.isCinemaOnlyUser,
    );
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
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
                  onRemoveProgress: _removeProgress,
                  onSwitchTab: _switchTab,
                ),
                CinemaSearchTab(
                  trendingGlobal: _trendingGlobal,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
                  onSwitchTab: _switchTab,
                ),
                CinemaBrowseTab(
                  key: ValueKey('browse-$_browseSeed'),
                  initialOptionId: _pendingBrowseOption,
                  onMediaTap: _showMediaDetails,
                  onPlayItem: _playMedia,
                  onToggleListItem: _toggleListItem,
                  onRateItem: _rateItem,
                  isInList: (item) =>
                      _watchlist.any((saved) => saved.tmdbId == item.tmdbId),
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
              ],
            ),
            // Floating back button (mobile/tablet): couple users return to
            // the dashboard; cinema-only profiles have no dashboard, so
            // they get a logout action instead (their only mobile exit,
            // mirroring the desktop profile menu).
            if (!isDesktop)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 10),
                    child: Tooltip(
                      message: isCoupleUser ? 'Dashboard' : 'Logout',
                      child: Material(
                        color: const Color(0xFF14101A),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0x1AFFFFFF)),
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
                                  await context.read<AuthService>().logout();
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
              child: NetflixCinemaTopBar(
                currentIndex: _currentIndex,
                scrolled: _desktopScrolled,
                onSelect: _onNavSelect,
                onAnimeTap: () => GoRouter.of(context).go('/anime'),
                onDashboardTap: isCoupleUser
                    ? () => GoRouter.of(context).go('/dashboard')
                    : null,
                onLogout: () async {
                  final router = GoRouter.of(context);
                  await context.read<AuthService>().logout();
                  if (!mounted) return;
                  router.go('/');
                },
                userName: userName,
                showAnime: isCinemaOnlyUser,
                links: const [
                  NetflixNavLink('Home', 0),
                  NetflixNavLink('New & Popular', 2, 'collection-new'),
                  NetflixNavLink('My List', 3),
                  NetflixNavLink('Search', 1),
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
      body: buildCinemaContent(),
      bottomNavigationBar: NetflixNavBar(
        scrolled: false,
        currentIndex: _currentIndex,
        links: const [
          NetflixNavLink('Home', 0),
          NetflixNavLink('New & Popular', 2, 'collection-new'),
          NetflixNavLink('My List', 3),
          NetflixNavLink('Search', 1),
        ],
        // Cinema-only profiles get Anime instead of Together here — it is
        // their only ride to `/anime` on mobile (no dashboard, and the
        // floating button is their logout).
        mobileItems: cinemaMobileNavItems(isCinemaOnlyUser: isCinemaOnlyUser),
        onSelect: _onNavSelect,
        onAnimeTap: () => GoRouter.of(context).go('/anime'),
      ),
    );
  }
}
