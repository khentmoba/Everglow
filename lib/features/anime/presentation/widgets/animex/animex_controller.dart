import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../cinema/data/services/tmdb_service.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/utils/optimistic_action.dart';

enum AnimexPage {
  home,
  browse,
  schedule,
  search,
  history,
  myList,
  playlists,
  seasonal,
}

/// Navigation + shared state for the anime section shell. Top-level pages
/// live in an [IndexedStack] so their scroll/data survive tab switches;
/// detail pages (watch, playlist detail) stack on top as full overlays.
class AnimeXController extends ChangeNotifier {
  AnimeXController({
    Stream<List<MediaItem>> Function(String)? watchlistStream,
    Future<List<MediaItem>> Function(List<MediaItem>)? refreshPosters,
  }) : _watchlistStream = watchlistStream,
       _refreshPosters = refreshPosters;

  final Stream<List<MediaItem>> Function(String)? _watchlistStream;
  final Future<List<MediaItem>> Function(List<MediaItem>)? _refreshPosters;
  late final TMDBService _tmdbService = TMDBService();
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  bool _postersRefreshed = false;
  String _libraryOwner = '';
  int _subscriptionGeneration = 0;
  int _snapshotGeneration = 0;
  bool _disposed = false;

  AnimexPage page = AnimexPage.home;
  final List<MediaItem> _library = [];
  final OptimisticSet<int> _optimisticAnime = OptimisticSet<int>();
  final Map<int, MediaItem> _optimisticAddedAnime = {};
  bool _libraryLoading = true;

  MediaItem? watchItem;
  int? watchEpisode;
  String? playlistId;
  bool dmcaOpen = false;

  // Browse-page preset applied when navigating from a "View All" link.
  String? browseSort;
  String? browseStatus;
  String? browseSeason;
  int? browseYear;
  String? browseGenre;

  List<MediaItem> get library => List.unmodifiable(_library);
  bool get libraryLoading => _libraryLoading;
  bool get hasDetail => watchItem != null || playlistId != null || dmcaOpen;

  /// Both History and Continue Watching read the same live account progress.
  List<AnimexHistoryEntry> get watchHistory => historyFromLibrary(_library);
  List<AnimexHistoryEntry> get continueWatching => watchHistory
      .where((entry) => entry.savedItem!.isCurrentlyWatching)
      .toList();

  static List<AnimexHistoryEntry> historyFromLibrary(List<MediaItem> library) {
    return library
        .where(
          (item) =>
              item.isAnime &&
              (item.currentEpisode != null ||
                  item.currentTimestamp != null ||
                  item.isCurrentlyWatching),
        )
        .map(AnimexHistoryEntry.fromMediaItem)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  MediaItem? savedAnime(MediaItem item) {
    for (final saved in _library) {
      if (item.anilistId != null && saved.anilistId != null) {
        if (item.anilistId == saved.anilistId) return saved;
      } else if (item.tmdbId > 0 && item.tmdbId == saved.tmdbId) {
        return saved;
      }
    }
    return null;
  }

  Future<void> clearWatchProgress(MediaItem item) async {
    final owner = _libraryOwner;
    if (owner.isEmpty) return;
    await _tmdbService.updateProgress(
      item,
      owner,
      status: item.isWatched ? 'watched-self' : 'to-watch',
    );
  }

  void initLibrary(BuildContext context) {
    loadLibrary(context.read<AuthService>().currentUser ?? '');
  }

  void loadLibrary(String userName) {
    if (_disposed) return;
    final subscription = ++_subscriptionGeneration;
    bool isCurrentSubscription() =>
        !_disposed &&
        subscription == _subscriptionGeneration &&
        _libraryOwner == userName;

    if (_libraryOwner != userName) {
      watchItem = null;
      watchEpisode = null;
      playlistId = null;
    }
    _libraryOwner = userName;
    _optimisticAnime.clearAll();
    _optimisticAddedAnime.clear();
    // Drop the previous profile's subscription AND items immediately so
    // one profile's My List never flashes for another on the same PWA.
    _watchlistSub?.cancel();
    _watchlistSub = null;
    _postersRefreshed = false;
    _library.clear();
    _libraryLoading = userName.isNotEmpty;
    notifyListeners();
    if (userName.isEmpty || !isCurrentSubscription()) return;
    _watchlistSub =
        (_watchlistStream ?? _tmdbService.getAnimeWatchListStream)(
          userName,
        ).listen(
          (items) async {
            if (!isCurrentSubscription()) return;
            final snapshot = ++_snapshotGeneration;
            _optimisticAnime.reconcile(items.map((m) => m.tmdbId));
            _optimisticAddedAnime.removeWhere(
              (id, _) => !_optimisticAnime.isAdded(id),
            );

            final effective = items
                .where((m) => !_optimisticAnime.isRemoved(m.tmdbId))
                .toList();
            for (final id in _optimisticAnime.added) {
              if (!effective.any((m) => m.tmdbId == id) &&
                  _optimisticAddedAnime.containsKey(id)) {
                effective.insert(0, _optimisticAddedAnime[id]!);
              }
            }

            // Account progress/removals must not wait for optional poster work.
            _library
              ..clear()
              ..addAll(effective);
            _libraryLoading = false;
            notifyListeners();
            if (_postersRefreshed ||
                !isCurrentSubscription() ||
                snapshot != _snapshotGeneration) {
              return;
            }

            try {
              final refreshed =
                  await (_refreshPosters ?? _tmdbService.refreshAnimePosters)(
                    effective,
                  );
              if (!isCurrentSubscription() || snapshot != _snapshotGeneration) {
                return;
              }
              _postersRefreshed = true;
              // Merge art only into still-present items, preserving optimistic
              // additions/removals made while the poster request was pending.
              final posters = {
                for (final item in refreshed) item.id: item.posterPath,
              };
              for (var i = 0; i < _library.length; i++) {
                final poster = posters[_library[i].id];
                if (poster != null) {
                  _library[i] = _library[i].copyWith(posterPath: poster);
                }
              }
              notifyListeners();
            } catch (error, stack) {
              if (!isCurrentSubscription() || snapshot != _snapshotGeneration) {
                return;
              }
              Logger.e(
                'AnimeX: account poster refresh failed',
                error: error,
                stackTrace: stack,
              );
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!isCurrentSubscription()) return;
            _libraryLoading = false;
            Logger.e(
              'AnimeX: account watchlist failed',
              error: error,
              stackTrace: stack,
            );
            notifyListeners();
          },
        );
  }

  void goTo(AnimexPage next) {
    if (page == next && !hasDetail) return;
    page = next;
    watchItem = null;
    playlistId = null;
    dmcaOpen = false;
    notifyListeners();
  }

  void presetBrowse({
    String? sort,
    String? status,
    String? season,
    int? year,
    String? genre,
  }) {
    browseSort = sort;
    browseStatus = status;
    browseSeason = season;
    browseYear = year;
    browseGenre = genre;
    goTo(AnimexPage.browse);
  }

  void openWatch(MediaItem item, {int? episode}) {
    watchItem = item;
    watchEpisode = episode;
    playlistId = null;
    dmcaOpen = false;
    notifyListeners();
  }

  void openPlaylist(String id) {
    playlistId = id;
    watchItem = null;
    dmcaOpen = false;
    notifyListeners();
  }

  void openDmca() {
    dmcaOpen = true;
    watchItem = null;
    playlistId = null;
    notifyListeners();
  }

  void closeDetail() {
    watchItem = null;
    playlistId = null;
    dmcaOpen = false;
    notifyListeners();
  }

  /// Optimistically removes [item] from the in-memory library immediately,
  /// then reconciles with Firestore in the background (rolling back on failure).
  Future<void> optimisticRemoveFromLibrary(
    MediaItem item,
    String userName,
  ) async {
    final index = _library.indexWhere((m) => m.tmdbId == item.tmdbId);
    if (index < 0) return;
    final removed = _library[index];

    await OptimisticAction.run(
      apply: () {
        _optimisticAnime.markRemoved(item.tmdbId);
        _optimisticAddedAnime.remove(item.tmdbId);
        _library.removeAt(index);
        notifyListeners();
      },
      action: () => _tmdbService.removeFromWatchList(item.tmdbId, userName),
      rollback: () {
        _optimisticAnime.rollbackRemove(item.tmdbId);
        if (!_library.any((m) => m.tmdbId == item.tmdbId)) {
          _library.insert(index.clamp(0, _library.length), removed);
          notifyListeners();
        }
      },
    );
  }

  /// Optimistically adds [item] to the in-memory library immediately,
  /// then reconciles with Firestore in the background (rolling back on failure).
  Future<void> optimisticAddToLibrary(
    MediaItem item,
    String userName, {
    String status = 'to-watch',
  }) async {
    if (_library.any((m) => m.tmdbId == item.tmdbId)) return;

    final addedItem = item.copyWith(status: status, userName: userName);
    await OptimisticAction.run(
      apply: () {
        _optimisticAnime.markAdded(item.tmdbId);
        _optimisticAddedAnime[item.tmdbId] = addedItem;
        _library.insert(0, addedItem);
        notifyListeners();
      },
      action: () => _tmdbService.saveToWatchList(item, status, userName),
      rollback: () {
        _optimisticAnime.rollbackAdd(item.tmdbId);
        _optimisticAddedAnime.remove(item.tmdbId);
        _library.removeWhere((m) => m.tmdbId == item.tmdbId);
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _watchlistSub?.cancel();
    super.dispose();
  }
}
