import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../cinema/data/models/media_item.dart';
import '../../../../cinema/data/services/tmdb_service.dart';
import '../../../../../core/services/auth_service.dart';

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
  final TMDBService _tmdbService = TMDBService();
  StreamSubscription<List<MediaItem>>? _watchlistSub;
  bool _postersRefreshed = false;

  AnimexPage page = AnimexPage.home;
  final List<MediaItem> _library = [];
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
    if (userName.isEmpty) return;
    _watchlistSub?.cancel();
    _postersRefreshed = false;
    _watchlistSub = _tmdbService.getAnimeWatchListStream(userName).listen((
      items,
    ) async {
      var refreshed = items;
      if (!_postersRefreshed) {
        refreshed = await _tmdbService.refreshAnimePosters(items);
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

  @override
  void dispose() {
    _watchlistSub?.cancel();
    super.dispose();
  }
}
