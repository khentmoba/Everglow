import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

/// One song in an artist showdown: how many times each person played it.
class ShowdownTrack {
  final String trackName;
  final int khentPlays;
  final int clairPlays;
  final String? imageUrl;
  final String spotifyUrl;

  const ShowdownTrack({
    required this.trackName,
    required this.khentPlays,
    required this.clairPlays,
    this.imageUrl,
    required this.spotifyUrl,
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
  /// `user.gettoptracks` at 1000 per request — plenty for a head-to-head
  /// over one artist.
  static const int _topTracksLimit = 1000;

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

  String get artist => _artist;
  bool get isLoading => _isLoading;
  int get khentTotal => _khentTotal;
  int get clairTotal => _clairTotal;
  List<ShowdownTrack> get tracks => _tracks;
  bool get hasData => _khentTotal > 0 || _clairTotal > 0;

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

  Future<void> selectArtist(String name) async {
    final artist = name.trim();
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
    final top = await _sync.fetchTopTracks(
      username,
      limit: _topTracksLimit,
    );
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
    }
    for (final t in clair) {
      clairTotal += t.playCount;
      final draft = byTrack.putIfAbsent(
        _key(t.trackName),
        () => _Draft(name: t.trackName, spotifyUrl: t.spotifyUrl),
      );
      draft.clair += t.playCount;
      draft.imageUrl ??= t.imageUrl;
    }
    final tracks = byTrack.values
        .map(
          (d) => ShowdownTrack(
            trackName: d.name,
            khentPlays: d.khent,
            clairPlays: d.clair,
            imageUrl: d.imageUrl,
            spotifyUrl: d.spotifyUrl,
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
