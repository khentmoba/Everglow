import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../data/models/loved_track.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_album.dart';
import '../../data/models/top_artist.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

class DiscoveryEntry {
  final String artistName;
  final DateTime? khentFirst;
  final DateTime? clairFirst;
  final String? winner; // 'khent' | 'clair' | 'tie' | null
  DiscoveryEntry({required this.artistName, this.khentFirst, this.clairFirst, this.winner});
}

class HeatmapData {
  final Map<DateTime, int> counts; // date (midnight) -> plays
  final int totalPlays;
  final int currentStreak;
  final int longestStreak;
  final int maxDaily;
  HeatmapData({required this.counts, required this.totalPlays, required this.currentStreak, required this.longestStreak, required this.maxDaily});
}

class MusicInsightsProvider extends ChangeNotifier {
  MusicInsightsProvider({MusicSyncService? syncService}) : _sync = syncService ?? MusicSyncService() {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    _init();
  }

  final MusicSyncService _sync;
  late final String _khentUser;
  late final String _clairUser;

  // ── Top artists/albums (overall) ──
  List<TopArtist> _khentArtists = [];
  List<TopArtist> _clairArtists = [];
  List<TopAlbum> _khentAlbums = [];
  List<TopAlbum> _clairAlbums = [];
  List<LovedTrack> _khentLoved = [];
  List<LovedTrack> _clairLoved = [];

  // Weekly (7day)
  List<TopMusicTrack> _khentWeeklyTracks = [];
  List<TopMusicTrack> _clairWeeklyTracks = [];
  List<TopArtist> _khentWeeklyArtists = [];
  List<TopArtist> _clairWeeklyArtists = [];
  List<TopAlbum> _khentWeeklyAlbums = [];
  List<TopAlbum> _clairWeeklyAlbums = [];

  // Heatmap
  HeatmapData? _khentHeatmap;
  HeatmapData? _clairHeatmap;

  // On This Day (last year same date)
  List<MusicStatus> _khentOnThisDay = [];
  List<MusicStatus> _clairOnThisDay = [];
  // Anniversary (Feb 14 last year)
  List<MusicStatus> _khentAnniversary = [];
  List<MusicStatus> _clairAnniversary = [];

  List<DiscoveryEntry> _discovery = [];

  bool _loading = true;
  bool _disposed = false;
  bool _artworkCachingDone = false;

  // Getters
  String get khentUser => _khentUser;
  String get clairUser => _clairUser;
  bool get isLoading => _loading;
  bool get hasAny => _khentArtists.isNotEmpty || _clairArtists.isNotEmpty || _khentLoved.isNotEmpty;

  List<TopArtist> get khentTopArtists => _khentArtists;
  List<TopArtist> get clairTopArtists => _clairArtists;
  List<TopAlbum> get khentTopAlbums => _khentAlbums;
  List<TopAlbum> get clairTopAlbums => _clairAlbums;
  List<LovedTrack> get khentLoved => _khentLoved;
  List<LovedTrack> get clairLoved => _clairLoved;

  List<TopMusicTrack> get khentWeeklyTracks => _khentWeeklyTracks;
  List<TopMusicTrack> get clairWeeklyTracks => _clairWeeklyTracks;
  List<TopArtist> get khentWeeklyArtists => _khentWeeklyArtists;
  List<TopArtist> get clairWeeklyArtists => _clairWeeklyArtists;
  List<TopAlbum> get khentWeeklyAlbums => _khentWeeklyAlbums;
  List<TopAlbum> get clairWeeklyAlbums => _clairWeeklyAlbums;

  HeatmapData? get khentHeatmap => _khentHeatmap;
  HeatmapData? get clairHeatmap => _clairHeatmap;

  List<MusicStatus> get khentOnThisDay => _khentOnThisDay;
  List<MusicStatus> get clairOnThisDay => _clairOnThisDay;
  List<MusicStatus> get khentAnniversary => _khentAnniversary;
  List<MusicStatus> get clairAnniversary => _clairAnniversary;

  List<DiscoveryEntry> get discovery => _discovery;

  // Compatibility
  int get compatibilityScore {
    if (_khentArtists.isEmpty || _clairArtists.isEmpty) return 0;
    final khentSet = _khentArtists.take(50).map((a) => a.name.toLowerCase()).toSet();
    final clairSet = _clairArtists.take(50).map((a) => a.name.toLowerCase()).toSet();
    final inter = khentSet.intersection(clairSet).length;
    final union = khentSet.union(clairSet).length;
    if (union == 0) return 0;
    final jaccard = inter / union;
    // also check track overlap boost
    // we don't have tracks here but we can weight by shared top track artists
    // Scale to 0-100 with a boost so small overlaps still feel meaningful
    final boosted = (jaccard * 100 * 1.6).clamp(0, 100).round();
    // Ensure at least showing something if there's any overlap
    if (inter > 0 && boosted < 12) return 12 + inter * 2;
    return boosted.clamp(0, 98);
  }

  List<TopArtist> get sharedArtists {
    if (_khentArtists.isEmpty || _clairArtists.isEmpty) return [];
    final clairMap = {for (final a in _clairArtists) a.name.toLowerCase(): a};
    final shared = <TopArtist>[];
    for (final a in _khentArtists) {
      if (clairMap.containsKey(a.name.toLowerCase())) shared.add(a);
      if (shared.length >= 6) break;
    }
    return shared;
  }

  List<TopArtist> get khentUniqueArtists {
    final clairSet = _clairArtists.map((a) => a.name.toLowerCase()).toSet();
    return _khentArtists.where((a) => !clairSet.contains(a.name.toLowerCase())).take(4).toList();
  }

  List<TopArtist> get clairUniqueArtists {
    final khentSet = _khentArtists.map((a) => a.name.toLowerCase()).toSet();
    return _clairArtists.where((a) => !khentSet.contains(a.name.toLowerCase())).take(4).toList();
  }

  Future<void> _init() async {
    try {
      await Future.wait([
        _loadOverall(),
        _loadWeekly(),
        _loadLoved(),
        _loadHeatmapAndHistory(),
      ]);
    } finally {
      _loading = false;
      _safeNotify();
      if (!_artworkCachingDone) {
        _artworkCachingDone = true;
        unawaited(_enrichWeeklyArtwork());
      }
    }
  }

  Future<void> _loadOverall() async {
    final results = await Future.wait([
      _sync.fetchTopArtists(_khentUser, limit: 50),
      _sync.fetchTopArtists(_clairUser, limit: 50),
      _sync.fetchTopAlbums(_khentUser, limit: 12),
      _sync.fetchTopAlbums(_clairUser, limit: 12),
    ]);
    if (_disposed) return;
    _khentArtists = results[0] as List<TopArtist>;
    _clairArtists = results[1] as List<TopArtist>;
    _khentAlbums = results[2] as List<TopAlbum>;
    _clairAlbums = results[3] as List<TopAlbum>;
    _safeNotify();
  }

  Future<void> _loadWeekly() async {
    final results = await Future.wait([
      _sync.fetchTopTracks(_khentUser, limit: 5, period: '7day'),
      _sync.fetchTopTracks(_clairUser, limit: 5, period: '7day'),
      _sync.fetchTopArtists(_khentUser, limit: 5, period: '7day'),
      _sync.fetchTopArtists(_clairUser, limit: 5, period: '7day'),
      _sync.fetchTopAlbums(_khentUser, limit: 3, period: '7day'),
      _sync.fetchTopAlbums(_clairUser, limit: 3, period: '7day'),
    ]);
    if (_disposed) return;
    _khentWeeklyTracks = results[0] as List<TopMusicTrack>;
    _clairWeeklyTracks = results[1] as List<TopMusicTrack>;
    _khentWeeklyArtists = results[2] as List<TopArtist>;
    _clairWeeklyArtists = results[3] as List<TopArtist>;
    _khentWeeklyAlbums = results[4] as List<TopAlbum>;
    _clairWeeklyAlbums = results[5] as List<TopAlbum>;
    _safeNotify();
  }

  Future<void> _loadLoved() async {
    final results = await Future.wait([
      _sync.fetchLovedTracks(_khentUser, limit: 12),
      _sync.fetchLovedTracks(_clairUser, limit: 12),
    ]);
    if (_disposed) return;
    _khentLoved = results[0] as List<LovedTrack>;
    _clairLoved = results[1] as List<LovedTrack>;
    _safeNotify();
  }

  Future<void> _loadHeatmapAndHistory() async {
    // Heatmap: last 84 days (12 weeks)
    final now = DateTime.now();
    final from84 = now.subtract(const Duration(days: 84));
    final fromSec = (from84.millisecondsSinceEpoch / 1000).floor();
    final toSec = (now.millisecondsSinceEpoch / 1000).floor();

    final heatResults = await Future.wait([
      _sync.fetchRecentTracksRange(_khentUser, limit: 200, from: fromSec, to: toSec, page: 1),
      _sync.fetchRecentTracksRange(_clairUser, limit: 200, from: fromSec, to: toSec, page: 1),
      _sync.fetchRecentTracksRange(_khentUser, limit: 200, from: fromSec, to: toSec, page: 2),
      _sync.fetchRecentTracksRange(_clairUser, limit: 200, from: fromSec, to: toSec, page: 2),
    ]);
    if (_disposed) return;
    final khentAll = [...heatResults[0] as List<MusicStatus>, ...heatResults[2] as List<MusicStatus>];
    final clairAll = [...heatResults[1] as List<MusicStatus>, ...heatResults[3] as List<MusicStatus>];

    _khentHeatmap = _buildHeatmap(khentAll, days: 84);
    _clairHeatmap = _buildHeatmap(clairAll, days: 84);

    // On This Day: same month/day last year 00:00-23:59
    final lastYear = DateTime(now.year - 1, now.month, now.day);
    final lFrom = DateTime(lastYear.year, lastYear.month, lastYear.day, 0, 0, 0);
    final lTo = DateTime(lastYear.year, lastYear.month, lastYear.day, 23, 59, 59);
    final otdResults = await Future.wait([
      _sync.fetchRecentTracksRange(_khentUser, limit: 50, from: (lFrom.millisecondsSinceEpoch / 1000).floor(), to: (lTo.millisecondsSinceEpoch / 1000).floor()),
      _sync.fetchRecentTracksRange(_clairUser, limit: 50, from: (lFrom.millisecondsSinceEpoch / 1000).floor(), to: (lTo.millisecondsSinceEpoch / 1000).floor()),
    ]);
    if (_disposed) return;
    _khentOnThisDay = otdResults[0] as List<MusicStatus>;
    _clairOnThisDay = otdResults[1] as List<MusicStatus>;

    // Anniversary: Feb 14 last year (or this year if after Feb 14)
    final annYear = now.month > 2 || (now.month == 2 && now.day >= 14) ? now.year : now.year - 1;
    // Show the most recent Feb 14 that is in the past
    final annDate = DateTime(annYear, 2, 14);
    final annFrom = DateTime(annDate.year, annDate.month, annDate.day, 0, 0, 0);
    final annTo = DateTime(annDate.year, annDate.month, annDate.day, 23, 59, 59);
    // If annDate is today, use last year's Feb14 instead for "anniversary soundtrack"
    DateTime effFrom = annFrom;
    DateTime effTo = annTo;
    if (annDate.year == now.year && annDate.month == now.month && annDate.day == now.day) {
      final prev = DateTime(annYear - 1, 2, 14);
      effFrom = DateTime(prev.year, prev.month, prev.day, 0, 0, 0);
      effTo = DateTime(prev.year, prev.month, prev.day, 23, 59, 59);
    }
    final annResults = await Future.wait([
      _sync.fetchRecentTracksRange(_khentUser, limit: 50, from: (effFrom.millisecondsSinceEpoch / 1000).floor(), to: (effTo.millisecondsSinceEpoch / 1000).floor()),
      _sync.fetchRecentTracksRange(_clairUser, limit: 50, from: (effFrom.millisecondsSinceEpoch / 1000).floor(), to: (effTo.millisecondsSinceEpoch / 1000).floor()),
    ]);
    if (_disposed) return;
    _khentAnniversary = annResults[0] as List<MusicStatus>;
    _clairAnniversary = annResults[1] as List<MusicStatus>;

    // Discovery race: find earliest for shared artists among those recent 200+200
    _discovery = _buildDiscovery(khentAll, clairAll);

    _safeNotify();
  }

  HeatmapData _buildHeatmap(List<MusicStatus> tracks, {required int days}) {
    final now = DateTime.now();
    final map = <DateTime, int>{};
    // init all days 0
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      map[d] = 0;
    }
    for (final t in tracks) {
      final ts = t.timestamp;
      if (ts == null) continue;
      final d = DateTime(ts.year, ts.month, ts.day);
      if (map.containsKey(d)) map[d] = (map[d] ?? 0) + 1;
    }
    final total = map.values.fold<int>(0, (a, b) => a + b);
    final maxDaily = map.values.isEmpty ? 0 : map.values.reduce((a, b) => a > b ? a : b);
    // streak: consecutive days from today backwards with >0
    int currentStreak = 0;
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if ((map[d] ?? 0) > 0) {
        currentStreak++;
      } else {
        if (i == 0) {
          // if today is 0, current streak is 0
          break;
        } else {
          break;
        }
      }
    }
    // longest streak in period
    int longest = 0;
    int cur = 0;
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if ((map[d] ?? 0) > 0) {
        cur++;
        if (cur > longest) longest = cur;
      } else {
        cur = 0;
      }
    }
    return HeatmapData(counts: map, totalPlays: total, currentStreak: currentStreak, longestStreak: longest, maxDaily: maxDaily);
  }

  List<DiscoveryEntry> _buildDiscovery(List<MusicStatus> khentAll, List<MusicStatus> clairAll) {
    // shared artists = intersection of artist names in the fetched windows plus top artists
    final khentArtists = {for (final t in khentAll) t.artistName.toLowerCase(): t.artistName};
    final clairArtists = {for (final t in clairAll) t.artistName.toLowerCase(): t.artistName};
    final sharedKeys = khentArtists.keys.toSet().intersection(clairArtists.keys.toSet());
    // also include shared top artists if not in recent window
    for (final a in sharedArtists) {
      sharedKeys.add(a.name.toLowerCase());
    }
    if (sharedKeys.isEmpty) return [];
    // build earliest map
    Map<String, DateTime?> khentEarliest = {};
    Map<String, DateTime?> clairEarliest = {};
    for (final key in sharedKeys) {
      khentEarliest[key] = null;
      clairEarliest[key] = null;
    }
    for (final t in khentAll) {
      final k = t.artistName.toLowerCase();
      if (!sharedKeys.contains(k) || t.timestamp == null) continue;
      final cur = khentEarliest[k];
      if (cur == null || t.timestamp!.isBefore(cur)) khentEarliest[k] = t.timestamp;
    }
    for (final t in clairAll) {
      final k = t.artistName.toLowerCase();
      if (!sharedKeys.contains(k) || t.timestamp == null) continue;
      final cur = clairEarliest[k];
      if (cur == null || t.timestamp!.isBefore(cur)) clairEarliest[k] = t.timestamp;
    }
    final entries = <DiscoveryEntry>[];
    for (final k in sharedKeys.take(6)) {
      final kh = khentEarliest[k];
      final cl = clairEarliest[k];
      String? winner;
      if (kh != null && cl != null) {
        if (kh.isBefore(cl)) winner = 'khent';
        if (cl.isBefore(kh)) winner = 'clair';
        if (kh.isAtSameMomentAs(cl)) winner = 'tie';
      } else if (kh != null) {
        winner = 'khent';
      } else if (cl != null) {
        winner = 'clair';
      }
      final displayName = khentArtists[k] ?? clairArtists[k] ?? k;
      entries.add(DiscoveryEntry(artistName: displayName, khentFirst: kh, clairFirst: cl, winner: winner));
    }
    // sort: winners first, then alphabetical
    entries.sort((a, b) {
      if (a.winner == 'khent' && b.winner != 'khent') return -1;
      if (b.winner == 'khent' && a.winner != 'khent') return 1;
      return a.artistName.compareTo(b.artistName);
    });
    return entries;
  }

  Future<void> _enrichWeeklyArtwork() async {
    // enrich weekly tracks missing artwork via MusicSyncService
    for (final list in [_khentWeeklyTracks, _clairWeeklyTracks]) {
      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        if (t.imageUrl != null) continue;
        final art = await _sync.fetchTrackArtwork(artist: t.artistName, track: t.trackName, mbid: t.mbid);
        if (_disposed || art == null) continue;
        list[i] = TopMusicTrack(rank: t.rank, trackName: t.trackName, artistName: t.artistName, playCount: t.playCount, imageUrl: art, spotifyUrl: t.spotifyUrl, mbid: t.mbid);
      }
    }
    _safeNotify();
  }

  Future<void> refresh() async {
    _loading = true;
    _safeNotify();
    await _init();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
