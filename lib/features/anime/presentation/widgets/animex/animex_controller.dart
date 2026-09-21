import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../cinema/data/models/media_item.dart';
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
  late final TMDBService _tmdbService = TMDBService();
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  bool _postersRefreshed = false;

  AnimexPage page = AnimexPage.home;
  final List<MediaItem> _library = [];
  final OptimisticSet<int> _optimisticAnime = OptimisticSet<int>();
  final Map<int, MediaItem> _optimisticAddedAnime = {};
  bool _libraryLoading = true;

  MediaItem? watchItem;
  int watchEpisode = 1;
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

  void initLibrary(BuildContext context) {
    final auth = context.read<AuthService>();
    final userName = auth.currentUser ?? '';
    // Drop the previous profile's subscription AND items immediately so
    // one profile's My List never flashes for another on the same PWA.
    _watchlistSub?.cancel();
    _watchlistSub = null;
    _postersRefreshed = false;
    _library.clear();
    _libraryLoading = userName.isNotEmpty;
    notifyListeners();
    if (userName.isEmpty) return;
    _watchlistSub = _tmdbService.getAnimeWatchListStream(userName).listen((
      items,
    ) async {
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

      var refreshed = effective;
      if (!_postersRefreshed) {
        refreshed = await _tmdbService.refreshAnimePosters(effective);
        _postersRefreshed = true;
      }
      _library
        ..clear()
        ..addAll(refreshed);
      _libraryLoading = false;
      notifyListeners();
    });
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

  void openWatch(MediaItem item, {int episode = 1}) {
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
    _watchlistSub?.cancel();
    super.dispose();
  }
}
