import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../data/models/artist_suggestion.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

/// One song in an artist showdown: how many times each person played it.
class ShowdownTrack {
  final String trackName;
  final int khentPlays;
  final int clairPlays;
  final String? imageUrl;
  final String spotifyUrl;
  final String? mbid;

  const ShowdownTrack({
    required this.trackName,
    required this.khentPlays,
    required this.clairPlays,
    this.imageUrl,
    required this.spotifyUrl,
    this.mbid,
  });

  int get combinedPlays => khentPlays + clairPlays;

  /// 'khent' | 'clair' | null when tied.
  String? get leader {
    if (khentPlays > clairPlays) return 'khent';
    if (clairPlays > khentPlays) return 'clair';
    return null;
  }
}

/// Khent vs Clair for any artist: head-to-head total plus the song-by-song
/// table. Results are cached per artist for the session so switching back
/// and forth never refetches.
///
/// Built on `user.gettoptracks` (limit 1000) filtered locally by artist.
/// The older `user.getartisttracks` endpoint is deprecated since 2019 and
/// returns individual scrobbles without playcounts from a stale backend,
/// so it always collapsed to "No plays yet" live.
class ArtistShowdownProvider extends ChangeNotifier {
  ArtistShowdownProvider({
    MusicSyncService? syncService,
    String initialArtist = ArtistShowdownProvider.defaultArtist,
  }) : _sync = syncService ?? MusicSyncService() {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    selectArtist(initialArtist);
  }

  static const String defaultArtist = 'Ethel Cain';

  /// How many top tracks per user to pull for filtering. Last.fm caps
  /// `user.gettoptracks` at 1000 per request, but 1000 frequently times
  /// out with backend error 500 for active accounts. 200 is reliable.
  static const int _topTracksLimit = 200;

  final MusicSyncService _sync;
  late final String _khentUser;
  late final String _clairUser;

  String _artist = '';
  bool _isLoading = true;
  bool _disposed = false;
  int _requestId = 0;

  int _khentTotal = 0;
  int _clairTotal = 0;
  List<ShowdownTrack> _tracks = const [];

  final Map<String, _CachedShowdown> _cache = {};

  List<ArtistSuggestion> _suggestions = const [];
  bool _isSearching = false;
  int _searchRequestId = 0;
  final Map<String, List<ArtistSuggestion>> _suggestionCache = {};
  final Map<String, String?> _artistImageCache = {};

  String get artist => _artist;
  bool get isLoading => _isLoading;
  int get khentTotal => _khentTotal;
  int get clairTotal => _clairTotal;
  List<ShowdownTrack> get tracks => _tracks;
  bool get hasData => _khentTotal > 0 || _clairTotal > 0;
  List<ArtistSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;

  /// 'khent' | 'clair' | null when tied or empty.
  String? get leader {
    if (!hasData) return null;
    if (_khentTotal > _clairTotal) return 'khent';
    if (_clairTotal > _khentTotal) return 'clair';
    return null;
  }

  /// Khent's share of the combined total (0..1) for the versus bar.
  double get khentShare {
    final total = _khentTotal + _clairTotal;
    if (total <= 0) return 0.5;
    return _khentTotal / total;
  }

  /// Live autocomplete: type "lana del" and pick "Lana Del Rey".
  /// Results are cached per query for the session; stale responses are
  /// dropped via [_searchRequestId] so fast typing never shows old rows.
  Future<void> searchArtists(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty || _isSearching) {
        _suggestions = const [];
        _isSearching = false;
        _safeNotify();
      }
      return;
    }
    final key = trimmed.toLowerCase();
    final cached = _suggestionCache[key];
    if (cached != null) {
      _suggestions = cached;
      _isSearching = false;
      _safeNotify();
      // A retype can hit the cache while an earlier enrichment pass is
      // still fetching photos — top up any rows still missing theirs.
      if (cached.any((s) => s.imageUrl == null)) {
        unawaited(_enrichSuggestionArtwork(_searchRequestId, key));
      }
      return;
    }
    final request = ++_searchRequestId;
    _isSearching = true;
    _safeNotify();
    final results = await _sync.fetchArtistSuggestions(trimmed);
    if (_disposed || request != _searchRequestId) return;
    _suggestionCache[key] = results;
    _suggestions = results;
    _isSearching = false;
    _safeNotify();
    // Last.fm ships no artist photos (placeholder-only since 2019), so
    // rows would all show the initial tile. Enrich from Spotify in the
    // background and pop photos in as they land.
    unawaited(_enrichSuggestionArtwork(request, key));
  }

  /// Fills in missing suggestion photos from Spotify without blocking the
  /// dropdown. Each hit updates the live list and the per-query cache so
  /// retyping finds photos instantly. Photos are also cached per artist so
  /// overlapping queries ("lana" vs "lana del") never refetch.
  Future<void> _enrichSuggestionArtwork(int request, String queryKey) async {
    for (var i = 0; i < _suggestions.length; i++) {
      if (_disposed || request != _searchRequestId) return;
      final current = _suggestions[i];
      if (current.imageUrl != null) continue;
      final artistKey = current.name.trim().toLowerCase();
      String? art;
      if (_artistImageCache.containsKey(artistKey)) {
        art = _artistImageCache[artistKey];
      } else {
        art = await _sync.fetchArtistImage(current.name);
        if (_disposed || request != _searchRequestId) return;
        _artistImageCache[artistKey] = art;
      }
      if (art == null || art.isEmpty) continue;
      final next = List<ArtistSuggestion>.from(_suggestions);
      next[i] = current.copyWith(imageUrl: art);
      _suggestions = next;
      _suggestionCache[queryKey] = next;
      _safeNotify();
    }
  }

  /// Hides the dropdown (after picking, submitting, or clearing the box).
  void clearSuggestions() {
    _searchRequestId++;
    if (_suggestions.isEmpty && !_isSearching) return;
    _suggestions = const [];
    _isSearching = false;
    _safeNotify();
  }

  Future<void> selectArtist(String name) async {
    final artist = name.trim();
    clearSuggestions();
    if (artist.isEmpty || artist == _artist) return;
    final key = artist.toLowerCase();
    final cached = _cache[key];
    if (cached != null) {
      _artist = artist;
      _khentTotal = cached.khentTotal;
      _clairTotal = cached.clairTotal;
      _tracks = cached.tracks;
      _isLoading = false;
      _safeNotify();
      return;
    }
    final request = ++_requestId;
    _artist = artist;
    _isLoading = true;
    _safeNotify();
    final results = await Future.wait([
      _tracksForArtist(_khentUser, artist),
      _tracksForArtist(_clairUser, artist),
    ]);
    if (_disposed || request != _requestId) return;
    final merged = _merge(results[0], results[1]);
    _khentTotal = merged.$1;
    _clairTotal = merged.$2;
    _tracks = merged.$3;
    _cache[key] = _CachedShowdown(
      khentTotal: _khentTotal,
      clairTotal: _clairTotal,
      tracks: _tracks,
    );
    _isLoading = false;
    _safeNotify();
    // `user.gettoptracks` rarely ships real covers, so rows would all fall
    // back to the music-note tile. Enrich missing artwork in the background
    // (Last.fm track.getinfo, then iTunes) and pop covers in as they land.
    unawaited(_enrichArtwork(request, key, artist));
  }

  /// Fills in missing covers for the current showdown without blocking the
  /// table. Each hit updates the live list and the per-artist cache so
  /// switching away and back keeps the artwork.
  Future<void> _enrichArtwork(
    int request,
    String cacheKey,
    String artist,
  ) async {
    for (var i = 0; i < _tracks.length; i++) {
      if (_disposed || request != _requestId) return;
      final current = _tracks[i];
      if (current.imageUrl != null) continue;
      final art = await _sync.fetchTrackArtwork(
        artist: artist,
        track: current.trackName,
        mbid: current.mbid,
      );
      if (_disposed || request != _requestId) return;
      if (art == null || art.isEmpty) continue;
      final next = List<ShowdownTrack>.from(_tracks);
      next[i] = ShowdownTrack(
        trackName: current.trackName,
        khentPlays: current.khentPlays,
        clairPlays: current.clairPlays,
        imageUrl: art,
        spotifyUrl: current.spotifyUrl,
        mbid: current.mbid,
      );
      _tracks = next;
      final cached = _cache[cacheKey];
      if (cached != null) {
        _cache[cacheKey] = _CachedShowdown(
          khentTotal: cached.khentTotal,
          clairTotal: cached.clairTotal,
          tracks: next,
        );
      }
      _safeNotify();
    }
  }

  /// Pulls each user's all-time top tracks once and keeps only rows for
  /// [artist] (case-insensitive, trimmed). This replaces the deprecated
  /// `user.getartisttracks` call, whose entries carry no `playcount` and
  /// whose backend is stale — both collapsed live totals to zero.
  Future<List<TopMusicTrack>> _tracksForArtist(
    String username,
    String artist,
  ) async {
    final wanted = artist.trim().toLowerCase();
    final top = await _sync.fetchTopTracks(username, limit: _topTracksLimit);
    return top
        .where((t) => t.artistName.trim().toLowerCase() == wanted)
        .toList();
  }

  /// Merges both users' track lists into one song-by-song table, sorted by
  /// combined plays. Matching is case-insensitive so "Strangers" and
  /// "strangers" count as the same song.
  static (int, int, List<ShowdownTrack>) _merge(
    List<TopMusicTrack> khent,
    List<TopMusicTrack> clair,
  ) {
    var khentTotal = 0;
    var clairTotal = 0;
    final byTrack = <String, _Draft>{};
    for (final t in khent) {
      khentTotal += t.playCount;
      final draft = byTrack.putIfAbsent(
        _key(t.trackName),
        () => _Draft(name: t.trackName, spotifyUrl: t.spotifyUrl),
      );
      draft.khent += t.playCount;
      draft.imageUrl ??= t.imageUrl;
      draft.mbid ??= t.mbid;
    }
    for (final t in clair) {
      clairTotal += t.playCount;
      final draft = byTrack.putIfAbsent(
        _key(t.trackName),
        () => _Draft(name: t.trackName, spotifyUrl: t.spotifyUrl),
      );
      draft.clair += t.playCount;
      draft.imageUrl ??= t.imageUrl;
      draft.mbid ??= t.mbid;
    }
    final tracks = byTrack.values
        .map(
          (d) => ShowdownTrack(
            trackName: d.name,
            khentPlays: d.khent,
            clairPlays: d.clair,
            imageUrl: d.imageUrl,
            spotifyUrl: d.spotifyUrl,
            mbid: d.mbid,
          ),
        )
        .toList();
    tracks.sort((a, b) => b.combinedPlays.compareTo(a.combinedPlays));
    return (khentTotal, clairTotal, tracks);
  }

  static String _key(String name) => name.trim().toLowerCase();

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Draft {
  _Draft({required this.name, required this.spotifyUrl});
  final String name;
  final String spotifyUrl;
  int khent = 0;
  int clair = 0;
  String? imageUrl;
  String? mbid;
}

class _CachedShowdown {
  const _CachedShowdown({
    required this.khentTotal,
    required this.clairTotal,
    required this.tracks,
  });
  final int khentTotal;
  final int clairTotal;
  final List<ShowdownTrack> tracks;
}
