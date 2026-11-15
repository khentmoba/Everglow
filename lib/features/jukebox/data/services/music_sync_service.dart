import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/config/env_config.dart';
import '../models/artist_suggestion.dart';
import '../models/loved_track.dart';
import '../models/music_status.dart';
import '../models/top_album.dart';
import '../models/top_artist.dart';
import '../models/top_music_track.dart';
import '../models/track_metadata.dart';
import '../models/lastfm_image_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';

export '../models/track_metadata.dart';

class MusicSyncService {
  MusicSyncService({
    http.Client? client,
    Future<Uri> Function(Uri url)? signUrl,
    CatalogProxyClient? proxyClient,
  }) : _client = client ?? http.Client(),
       _proxy = proxyClient ?? CatalogProxyClient(client: client),
       _signUrl = signUrl;

  final http.Client _client;
  final CatalogProxyClient _proxy;
  final Future<Uri> Function(Uri url)? _signUrl;

  final String _baseUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfm';

  final String _spotifyBaseUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxySpotifySearch';

  static String? _cachedToken;
  static DateTime? _cachedAt;
  static Future<String?>? _inFlightToken;

  Future<String?> _getTokenCached() async {
    final now = DateTime.now();
    if (_cachedToken != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!).inMinutes < 4) {
      return _cachedToken;
    }
    if (_inFlightToken != null) return _inFlightToken!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    _inFlightToken = user.getIdToken();
    try {
      _cachedToken = await _inFlightToken;
      _cachedAt = DateTime.now();
      return _cachedToken;
    } finally {
      _inFlightToken = null;
    }
  }

  Future<http.Response> _getWithAuth(Uri url) async {
    final signUrl = _signUrl;
    final signed = signUrl == null ? url : await signUrl(url);
    final token = signUrl == null ? await _getTokenCached() : null;
    if (signUrl == null && (token == null || token.isEmpty)) {
      throw StateError('Last.fm requires an authenticated user');
    }
    for (var attempt = 0; ; attempt++) {
      final response = await _client
          .get(
            signed,
            headers: token == null ? null : {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      if (attempt == 1 ||
          !const [502, 503, 504].contains(response.statusCode)) {
        return response;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static final Set<String> _invalidUsers = <String>{};

  bool isUserInvalid(String username) => _invalidUsers.contains(username);

  static void resetInvalidUsers() => _invalidUsers.clear();

  static bool _isCoupleUser(String username) {
    final lower = username.toLowerCase();
    return lower == EnvConfig.lastfmUserKhent.toLowerCase() ||
        lower == EnvConfig.lastfmUserClair.toLowerCase();
  }

  static void _markInvalidUser(String username) {
    if (_isCoupleUser(username)) return;
    _invalidUsers.add(username);
  }

  final Map<String, int> _lastObservedTotalPlays = {};
  int _transientFailureCount = 0;

  int get transientFailureCount => _transientFailureCount;

  int getLastObservedTotalPlays(String username) =>
      _lastObservedTotalPlays[username.toLowerCase()] ?? 0;

  List<Map<String, dynamic>> _asMapList(dynamic node) {
    if (node is List) return node.whereType<Map<String, dynamic>>().toList();
    if (node is Map<String, dynamic>) return [node];
    if (node is Map) return [Map<String, dynamic>.from(node)];
    return const [];
  }

  void _warnOnLastfmError(dynamic data, String what, String username) {
    final error = data is Map ? data['error'] : null;
    final message = data is Map ? data['message'] : null;
    if (error != null || message != null) {
      _transientFailureCount++;
      Logger.w(
        'Jukebox Service: Last.fm error for $what ($username): '
        '[$error] $message',
      );
    } else {
      Logger.d('Jukebox Service: No $what found for $username in response.');
    }
  }

  Future<MusicStatus?> fetchRecentTrack(String username) async {
    final tracks = await fetchRecentTracks(username, limit: 1);
    return tracks.isEmpty ? null : tracks.first;
  }

  Future<List<MusicStatus>> fetchRecentTracks(
    String username, {
    int limit = 5,
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getrecenttracks&user=$username&format=json&limit=$limit',
      );

      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawTotal =
            data['recenttracks']?['@attr']?['total']?.toString() ?? '';
        final total = int.tryParse(rawTotal);
        if (total != null && total > 0) {
          _lastObservedTotalPlays[username.toLowerCase()] = total;
        }
        final tracks = _asMapList(data['recenttracks']?['track']);
        if (tracks.isNotEmpty) {
          return tracks
              .map((track) => MusicStatus.fromTrackJson(track, username))
              .toList();
        } else {
          _warnOnLastfmError(data, 'tracks', username);
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.',
        );
      } else {
        _transientFailureCount++;
        Logger.e(
          'Jukebox Service Error ($username): Status ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      _transientFailureCount++;
      Logger.e(
        'Jukebox Service Timeout: API call for $username timed out after 10s.',
      );
    } catch (e) {
      _transientFailureCount++;
      Logger.e('Jukebox Service Exception ($username)', error: e);
    }
    return [];
  }

  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    int page = 1,
    String period = 'overall',
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettoptracks&user=$username&period=$period'
        '&limit=$limit&page=$page&format=json',
      );

      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(data['toptracks']?['track']);
        if (tracks.isNotEmpty) {
          final parsed = <TopMusicTrack>[];
          for (var i = 0; i < tracks.length; i++) {
            parsed.add(TopMusicTrack.fromJson(tracks[i]));
          }
          parsed.sort((a, b) {
            final cmp = b.playCount.compareTo(a.playCount);
            if (cmp != 0) return cmp;
            final rankA = a.rank > 0 ? a.rank : 999;
            final rankB = b.rank > 0 ? b.rank : 999;
            return rankA.compareTo(rankB);
          });
          for (var i = 0; i < parsed.length; i++) {
            parsed[i] = parsed[i].copyWith(rank: i + 1);
          }
          return parsed;
        } else {
          _warnOnLastfmError(data, 'top tracks', username);
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.',
        );
      } else if (response.statusCode == 500 && limit > 200) {
        Logger.w(
          'Jukebox Service: Last.fm returned 500 for limit=$limit on "$username". Retrying with limit=200...',
        );
        return await fetchTopTracks(
          username,
          limit: 200,
          page: page,
          period: period,
        );
      } else {
        _transientFailureCount++;
        Logger.e(
          'Jukebox Service Error (top tracks, $username): Status ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      _transientFailureCount++;
      Logger.e(
        'Jukebox Service Timeout: Top tracks API call for $username timed out after 10s.',
      );
    } catch (e) {
      _transientFailureCount++;
      Logger.e('Jukebox Service Exception (top tracks, $username)', error: e);
    }
    return [];
  }

  Future<List<TopMusicTrack>> fetchTopTracksPaged(
    String username, {
    int pageSize = 200,
    int maxPages = 5,
    String period = 'overall',
  }) async {
    final all = <TopMusicTrack>[];
    for (var page = 1; page <= maxPages; page++) {
      final rows = await fetchTopTracks(
        username,
        limit: pageSize,
        page: page,
        period: period,
      );
      all.addAll(rows);
      if (rows.length < pageSize) break;
      if (_invalidUsers.contains(username)) break;
    }
    return all;
  }

  Future<List<TopMusicTrack>> fetchArtistCatalogTracks(
    String artist, {
    int page = 1,
    int limit = 50,
  }) async {
    final trimmedArtist = artist.trim();
    if (trimmedArtist.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl?method=artist.gettoptracks'
        '&artist=${Uri.encodeComponent(trimmedArtist)}'
        '&limit=$limit&page=$page&autocorrect=1&format=json',
      );
      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(data['toptracks']?['track']);
        if (tracks.isNotEmpty) {
          final parsed = <TopMusicTrack>[];
          for (var i = 0; i < tracks.length; i++) {
            final t = tracks[i];
            final name = (t['name'] as String?)?.trim() ?? '';
            if (name.isEmpty) continue;
            final rank =
                int.tryParse(t['@attr']?['rank']?.toString() ?? '') ?? (i + 1);
            final mbid = (t['mbid'] as String?)?.trim();
            final playCount =
                int.tryParse(t['playcount']?.toString() ?? '') ?? 0;
            final images = t['image'] as List<dynamic>?;
            final imageUrl = pickLastfmImageUrl(images);
            parsed.add(
              TopMusicTrack(
                rank: rank,
                trackName: name,
                artistName: trimmedArtist,
                playCount: playCount,
                imageUrl: imageUrl,
                spotifyUrl:
                    'https://open.spotify.com/search/${Uri.encodeComponent('$trimmedArtist $name')}',
                mbid: (mbid != null && mbid.isNotEmpty) ? mbid : null,
              ),
            );
          }
          return parsed;
        } else {
          _warnOnLastfmError(data, 'artist catalog tracks', trimmedArtist);
        }
      } else {
        _transientFailureCount++;
        Logger.w(
          'Jukebox Service: Artist catalog tracks ($trimmedArtist) status ${response.statusCode}',
        );
      }
    } on TimeoutException {
      _transientFailureCount++;
      Logger.w(
        'Jukebox Service Timeout: Artist catalog tracks for "$trimmedArtist" timed out.',
      );
    } catch (e) {
      _transientFailureCount++;
      Logger.w(
        'Jukebox Service Exception (artist catalog tracks, $trimmedArtist)',
        error: e,
      );
    }
    return [];
  }

  Future<List<TopMusicTrack>> fetchArtistCatalogTracksAll(
    String artist, {
    int pageSize = 50,
    int maxPages = 10,
  }) async {
    final all = <TopMusicTrack>[];
    final seenNames = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final rows = await fetchArtistCatalogTracks(
        artist,
        page: page,
        limit: pageSize,
      );
      if (rows.isEmpty) break;
      for (final track in rows) {
        if (seenNames.add(track.trackName.toLowerCase())) {
          all.add(track);
        }
      }
      if (rows.length < pageSize) break;
    }
    return all;
  }

  Future<int> fetchArtistUserPlayCount({
    required String username,
    required String artist,
  }) async {
    final trimmedArtist = artist.trim();
    if (username.isEmpty ||
        trimmedArtist.isEmpty ||
        _invalidUsers.contains(username)) {
      return 0;
    }
    try {
      final url = Uri.parse(
        '$_baseUrl?method=artist.getinfo'
        '&artist=${Uri.encodeComponent(trimmedArtist)}'
        '&username=${Uri.encodeComponent(username)}'
        '&autocorrect=1&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawCount = data['artist']?['stats']?['userplaycount'];
        if (rawCount != null) {
          return int.tryParse(rawCount.toString()) ?? 0;
        }
      }
    } catch (e) {
      Logger.w(
        'Jukebox Service: failed to fetch artist user play count ($username, $trimmedArtist)',
        error: e,
      );
    }
    return 0;
  }

  Future<int> fetchTrackUserPlayCount({
    required String username,
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final trimmedArtist = artist.trim();
    final trimmedTrack = track.trim();
    if (username.isEmpty ||
        trimmedArtist.isEmpty ||
        trimmedTrack.isEmpty ||
        _invalidUsers.contains(username)) {
      return 0;
    }

    try {
      final buffer = StringBuffer(
        '$_baseUrl?method=track.getinfo&format=json'
        '&username=${Uri.encodeComponent(username)}'
        '&autocorrect=1',
      );
      if (mbid != null && mbid.isNotEmpty) {
        buffer.write('&mbid=${Uri.encodeComponent(mbid)}');
      } else {
        buffer.write(
          '&artist=${Uri.encodeComponent(trimmedArtist)}'
          '&track=${Uri.encodeComponent(trimmedTrack)}',
        );
      }

      final url = Uri.parse(buffer.toString());
      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trackNode = data['track'];
        if (trackNode is Map) {
          final raw = trackNode['userplaycount']?.toString();
          return int.tryParse(raw ?? '') ?? 0;
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        _transientFailureCount++;
      }
    } on TimeoutException {
      _transientFailureCount++;
      Logger.d(
        'Jukebox Service Timeout: track playcount for "$trimmedArtist - $trimmedTrack" timed out.',
      );
    } catch (e) {
      _transientFailureCount++;
      Logger.w(
        'Jukebox Service Exception (track playcount, $trimmedArtist - $trimmedTrack, $username)',
        error: e,
      );
    }
    return 0;
  }

  Future<List<TopMusicTrack>> fetchUserArtistTracks(
    String username,
    String artist, {
    required List<TopMusicTrack> candidateTracks,
    int batchSize = 8,
  }) async {
    final trimmedArtist = artist.trim();
    if (username.isEmpty ||
        trimmedArtist.isEmpty ||
        candidateTracks.isEmpty ||
        _invalidUsers.contains(username)) {
      return [];
    }

    final playedTracks = <TopMusicTrack>[];
    for (var i = 0; i < candidateTracks.length; i += batchSize) {
      if (_invalidUsers.contains(username)) break;
      final batch = candidateTracks.skip(i).take(batchSize).toList();
      final playCounts = await Future.wait(
        batch.map(
          (t) => fetchTrackUserPlayCount(
            username: username,
            artist: trimmedArtist,
            track: t.trackName,
            mbid: t.mbid,
          ),
        ),
      );

      for (var j = 0; j < batch.length; j++) {
        final count = playCounts[j];
        if (count > 0) {
          final track = batch[j];
          playedTracks.add(
            TopMusicTrack(
              rank: playedTracks.length + 1,
              trackName: track.trackName,
              artistName: trimmedArtist,
              playCount: count,
              imageUrl: track.imageUrl,
              spotifyUrl: track.spotifyUrl,
              mbid: track.mbid,
            ),
          );
        }
      }
    }

    playedTracks.sort((a, b) => b.playCount.compareTo(a.playCount));
    for (var i = 0; i < playedTracks.length; i++) {
      playedTracks[i] = TopMusicTrack(
        rank: i + 1,
        trackName: playedTracks[i].trackName,
        artistName: playedTracks[i].artistName,
        playCount: playedTracks[i].playCount,
        imageUrl: playedTracks[i].imageUrl,
        spotifyUrl: playedTracks[i].spotifyUrl,
        mbid: playedTracks[i].mbid,
      );
    }
    return playedTracks;
  }

  @Deprecated('Use fetchTopTracks(limit: 1000) filtered by artist instead')
  Future<List<TopMusicTrack>> fetchArtistTracks(
    String username,
    String artist, {
    int limit = 200,
  }) async {
    if (username.isEmpty ||
        artist.isEmpty ||
        _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getartisttracks&user=$username'
        '&artist=${Uri.encodeComponent(artist)}&limit=$limit&format=json',
      );

      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(data['artisttracks']?['track']);
        if (tracks.isNotEmpty) {
          final parsed = <TopMusicTrack>[];
          for (var i = 0; i < tracks.length; i++) {
            final track = TopMusicTrack.fromJson(tracks[i]);
            parsed.add(
              TopMusicTrack(
                rank: track.rank > 0 ? track.rank : i + 1,
                trackName: track.trackName,
                artistName: artist,
                playCount: track.playCount,
                imageUrl: track.imageUrl,
                spotifyUrl:
                    'https://open.spotify.com/search/${Uri.encodeComponent('$artist ${track.trackName}')}',
                mbid: track.mbid,
              ),
            );
          }
          return parsed;
        } else {
          _warnOnLastfmError(data, 'artist tracks', username);
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.',
        );
      } else {
        Logger.e(
          'Jukebox Service Error (artist tracks, $username): Status ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Artist tracks API call for $username timed out after 10s.',
      );
    } catch (e) {
      Logger.e(
        'Jukebox Service Exception (artist tracks, $username)',
        error: e,
      );
    }
    return [];
  }

  Future<int> fetchUserTotalPlays(String username) async {
    if (username.isEmpty || _invalidUsers.contains(username)) {
      return getLastObservedTotalPlays(username);
    }
    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getinfo&user=$username&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['user'];
        if (user is Map) {
          final raw = user['playcount']?.toString() ?? '';
          final parsed = int.tryParse(raw);
          if (parsed != null && parsed > 0) {
            _lastObservedTotalPlays[username.toLowerCase()] = parsed;
            return parsed;
          }
        } else {
          _warnOnLastfmError(data, 'user info', username);
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found (user.getInfo).',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: user.getInfo for $username timed out.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception (user.getInfo, $username)', error: e);
    }
    return getLastObservedTotalPlays(username);
  }

  Future<String?> fetchTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final lastfmArtwork = await _fetchLastfmTrackArtwork(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    if (lastfmArtwork != null) return lastfmArtwork;
    final itunesArtwork = await _fetchItunesArtwork(
      artist: artist,
      track: track,
    );
    if (itunesArtwork != null) return itunesArtwork;
    return _fetchSpotifyArtwork(artist: artist, track: track);
  }

  Future<TrackMetadata?> fetchTrackMetadata({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final lastfmMeta = await _fetchLastfmTrackMetadata(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    if (lastfmMeta != null &&
        lastfmMeta.artworkUrl != null &&
        lastfmMeta.albumName != null &&
        lastfmMeta.albumName!.isNotEmpty) {
      return lastfmMeta;
    }

    final itunesMeta = await _fetchItunesMetadata(artist: artist, track: track);
    if (itunesMeta != null) {
      final combinedArtwork = lastfmMeta?.artworkUrl ?? itunesMeta.artworkUrl;
      final combinedAlbum =
          (lastfmMeta?.albumName != null && lastfmMeta!.albumName!.isNotEmpty)
          ? lastfmMeta.albumName
          : itunesMeta.albumName;
      if (combinedArtwork != null &&
          combinedAlbum != null &&
          combinedAlbum.isNotEmpty) {
        return TrackMetadata(
          artworkUrl: combinedArtwork,
          albumName: combinedAlbum,
        );
      }
    }

    final spotifyMeta = await _fetchSpotifyMetadata(
      artist: artist,
      track: track,
    );
    if (spotifyMeta != null) {
      final combinedArtwork =
          lastfmMeta?.artworkUrl ??
          itunesMeta?.artworkUrl ??
          spotifyMeta.artworkUrl;
      final combinedAlbum =
          (lastfmMeta?.albumName != null && lastfmMeta!.albumName!.isNotEmpty)
          ? lastfmMeta.albumName
          : (itunesMeta?.albumName != null && itunesMeta!.albumName!.isNotEmpty)
          ? itunesMeta.albumName
          : spotifyMeta.albumName;
      return TrackMetadata(
        artworkUrl: combinedArtwork,
        albumName: combinedAlbum,
      );
    }

    if (itunesMeta != null) {
      return TrackMetadata(
        artworkUrl: lastfmMeta?.artworkUrl ?? itunesMeta.artworkUrl,
        albumName:
            (lastfmMeta?.albumName != null && lastfmMeta!.albumName!.isNotEmpty)
            ? lastfmMeta.albumName
            : itunesMeta.albumName,
      );
    }

    return lastfmMeta;
  }

  Future<String?> fetchTrackAlbum({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final meta = await fetchTrackMetadata(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    return meta?.albumName;
  }

  Future<String?> _fetchLastfmTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final meta = await _fetchLastfmTrackMetadata(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    return meta?.artworkUrl;
  }

  Future<TrackMetadata?> _fetchLastfmTrackMetadata({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    try {
      final buffer = StringBuffer('$_baseUrl?method=track.getinfo&format=json');
      if (mbid != null && mbid.isNotEmpty) {
        buffer.write('&mbid=${Uri.encodeComponent(mbid)}');
      } else {
        buffer.write(
          '&artist=${Uri.encodeComponent(artist)}'
          '&track=${Uri.encodeComponent(track)}',
        );
      }

      final url = Uri.parse(buffer.toString());
      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trackNode = data['track'];
        if (trackNode is Map &&
            _matchesTrack(
              trackNode['name'],
              _artistNameOf(trackNode['artist']),
              track: track,
              artist: artist,
            )) {
          final album = trackNode['album'];
          if (album is Map) {
            final picked = pickLastfmImageUrl(album['image'] as List<dynamic>?);
            final title = (album['title'] as String?)?.trim();
            final validTitle = (title != null && title.isNotEmpty)
                ? title
                : null;
            if (picked != null || validTitle != null) {
              return TrackMetadata(artworkUrl: picked, albumName: validTitle);
            }
          }
        } else {
          Logger.d(
            'Jukebox Service: track.getinfo mismatch for '
            '"$artist - $track" — ignoring its cover.',
          );
        }
        return null;
      } else {
        Logger.d(
          'Jukebox Service: track.getinfo returned ${response.statusCode} '
          'for "$artist - $track"',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: track.getinfo timed out for "$artist - $track".',
      );
    } catch (e) {
      Logger.e(
        'Jukebox Service Exception (track.getinfo, $artist - $track)',
        error: e,
      );
    }
    return null;
  }

  Future<String?> _fetchItunesArtwork({
    required String artist,
    required String track,
  }) async {
    final meta = await _fetchItunesMetadata(artist: artist, track: track);
    return meta?.artworkUrl;
  }

  Future<TrackMetadata?> _fetchItunesMetadata({
    required String artist,
    required String track,
  }) async {
    try {
      final results = await _searchItunes('$artist $track');
      var selected = _selectItunesResult(results, track: track, artist: artist);
      if (selected == null) {
        final retry = await _searchItunes(track);
        selected = _selectItunesResult(
          retry,
          track: track,
          artist: _hasNonAscii(artist) ? null : artist,
        );
      }
      if (selected == null) return null;
      final artwork = selected['artworkUrl100'];
      final albumName = (selected['collectionName'] as String?)?.trim();
      final validAlbum = (albumName != null && albumName.isNotEmpty)
          ? albumName
          : null;
      final validArtwork = (artwork is String && artwork.isNotEmpty)
          ? artwork.replaceFirst('/100x100bb.jpg', '/600x600bb.jpg')
          : null;

      if (validArtwork != null || validAlbum != null) {
        return TrackMetadata(artworkUrl: validArtwork, albumName: validAlbum);
      }
      return null;
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: iTunes artwork lookup timed out for '
        '"$artist - $track".',
      );
    } catch (e) {
      Logger.e(
        'Jukebox Service Exception (iTunes artwork, $artist - $track)',
        error: e,
      );
    }
    return null;
  }

  Future<String?> _fetchSpotifyArtwork({
    required String artist,
    required String track,
  }) async {
    final meta = await _fetchSpotifyMetadata(artist: artist, track: track);
    return meta?.artworkUrl;
  }

  Future<TrackMetadata?> _fetchSpotifyMetadata({
    required String artist,
    required String track,
  }) async {
    try {
      final url = Uri.parse(
        '$_spotifyBaseUrl?artist=${Uri.encodeComponent(artist)}'
        '&track=${Uri.encodeComponent(track)}',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map &&
            _matchesTrack(
              data['trackName'],
              data['artistName'],
              track: track,
              artist: artist,
            )) {
          final img = data['imageUrl'];
          final album = (data['albumName'] as String?)?.trim();
          final validImg = (img is String && img.isNotEmpty) ? img : null;
          final validAlbum = (album != null && album.isNotEmpty) ? album : null;
          if (validImg != null || validAlbum != null) {
            return TrackMetadata(artworkUrl: validImg, albumName: validAlbum);
          }
        } else {
          Logger.d(
            'Jukebox Service: Spotify match rejected for '
            '"$artist - $track".',
          );
        }
        return null;
      }
      Logger.d(
        'Jukebox Service: proxySpotifySearch returned '
        '${response.statusCode} for "$artist - $track"',
      );
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Spotify artwork lookup timed out for '
        '"$artist - $track".',
      );
    } catch (e) {
      Logger.e(
        'Jukebox Service Exception (Spotify artwork, $artist - $track)',
        error: e,
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _searchItunes(String term) async {
    final query = {
      'term': term,
      'entity': 'song',
      'media': 'music',
      'limit': '10',
    };
    http.Response response;
    if (kIsWeb) {
      response = await _proxy.get(
        'itunes',
        'search',
        query: query,
        timeout: const Duration(seconds: 8),
      );
    } else {
      final uri = Uri.parse(
        'https://itunes.apple.com/search',
      ).replace(queryParameters: query);
      response = await _client.get(uri).timeout(const Duration(seconds: 8));
    }
    if (response.statusCode != 200) return const [];
    final data = json.decode(response.body);
    final results = data is Map<String, dynamic> ? data['results'] : null;
    if (results is! List) return const [];
    return results.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic>? _selectItunesResult(
    List<Map<String, dynamic>> results, {
    required String track,
    String? artist,
  }) {
    if (results.isEmpty) return null;
    for (final result in results) {
      if (_matchesTrack(
        result['trackName'],
        result['artistName'],
        track: track,
        artist: artist,
      )) {
        return result;
      }
    }
    return null;
  }

  bool _matchesTrack(
    dynamic candidateTrack,
    dynamic candidateArtist, {
    required String track,
    String? artist,
  }) {
    if (candidateTrack is! String) return false;
    if (_normalizeTrackBase(candidateTrack) != _normalizeTrackBase(track)) {
      return false;
    }
    if (artist == null) return true;
    if (candidateArtist is! String) return false;
    return _artistMatches(artist, candidateArtist);
  }

  static String _normalizeTrackBase(String title) {
    var base = title;
    base = base.replaceAll(
      RegExp(
        r'\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring|with)\b[^\]\)]*[\]\)]',
        caseSensitive: false,
      ),
      '',
    );
    base = base.replaceAll(
      RegExp(
        r'(?:^|[\s–—:\-]+)(?:feat\.?|ft\.?|featuring)\b.*$',
        caseSensitive: false,
      ),
      '',
    );
    final withMatch = RegExp(
      r'^(.*\S)\s+with\b(.*)$',
      caseSensitive: false,
    ).firstMatch(base);
    if (withMatch != null &&
        withMatch.group(1)!.trim().split(RegExp(r'\s+')).length >= 2) {
      base = withMatch.group(1)!;
    }
    return _normalizeForMatch(base);
  }

  static bool _artistMatches(String a, String b) {
    final na = _normalizeForMatch(a);
    final nb = _normalizeForMatch(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final pa = _splitArtists(a);
    final pb = _splitArtists(b);
    for (final x in pa) {
      for (final y in pb) {
        if (x == y) return true;
        if (x.length >= 4 && y.contains(x)) return true;
        if (y.length >= 4 && x.contains(y)) return true;
      }
    }
    if (na.length >= 4 && nb.contains(na)) return true;
    if (nb.length >= 4 && na.contains(nb)) return true;
    return false;
  }

  static List<String> _splitArtists(String value) {
    final parts = value.split(
      RegExp(
        r'\s*(?:&|,|;|/|\+|×|\bx\b|\band\b|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b|\bwith\b|\bvs\.?\b)+\s*',
        caseSensitive: false,
      ),
    );
    return parts.map(_normalizeForMatch).where((p) => p.length >= 2).toList();
  }

  static String? _artistNameOf(dynamic artistNode) {
    if (artistNode is Map) {
      final name = artistNode['name'];
      return name is String ? name : null;
    }
    return artistNode is String ? artistNode : null;
  }

  static bool _hasNonAscii(String value) =>
      value.runes.any((rune) => rune > 127);

  Future<List<ArtistSuggestion>> fetchArtistSuggestions(
    String query, {
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    try {
      final url = Uri.parse(
        '$_baseUrl?method=artist.search'
        '&artist=${Uri.encodeComponent(trimmed)}'
        '&limit=$limit&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artists = _asMapList(
          data['results']?['artistmatches']?['artist'],
        );
        if (artists.isNotEmpty) {
          return artists
              .map(ArtistSuggestion.fromJson)
              .where((a) => a.name.isNotEmpty)
              .toList();
        }
      } else {
        Logger.e(
          'Jukebox Service Error (artist search, $trimmed): '
          '${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Artist search for "$trimmed" timed out.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception (artist search, $trimmed)', error: e);
    }
    return const [];
  }

  Future<String?> fetchArtistImage(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return null;
    try {
      final url = Uri.parse(
        '$_spotifyBaseUrl?type=artist&artist=${Uri.encodeComponent(name)}',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final img = data['imageUrl'] as String?;
          if (img != null && img.isNotEmpty) return img;
        }
      }
    } on TimeoutException {
      Logger.e('Jukebox Service Timeout: Artist photo for "$name" timed out.');
    } catch (e) {
      Logger.e('Jukebox Service Exception (artist photo, $name)', error: e);
    }
    return null;
  }

  Future<List<TopArtist>> fetchTopArtists(
    String username, {
    int limit = 10,
    String period = 'overall',
    int page = 1,
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) return [];
    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettopartists&user=$username&period=$period'
        '&limit=$limit&page=$page&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artists = _asMapList(data['topartists']?['artist']);
        if (artists.isNotEmpty) {
          return artists.map(TopArtist.fromJson).toList();
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        Logger.e(
          'Jukebox Service Error (top artists, $username): ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e('Jukebox Service Timeout: Top artists for $username timed out.');
    } catch (e) {
      Logger.e('Jukebox Service Exception (top artists, $username)', error: e);
    }
    return [];
  }

  Future<List<TopAlbum>> fetchTopAlbums(
    String username, {
    int limit = 10,
    String period = 'overall',
    int page = 1,
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) return [];
    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettopalbums&user=$username&period=$period'
        '&limit=$limit&page=$page&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final albums = _asMapList(data['topalbums']?['album']);
        if (albums.isNotEmpty) {
          return albums.map(TopAlbum.fromJson).toList();
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        Logger.e(
          'Jukebox Service Error (top albums, $username): ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e('Jukebox Service Timeout: Top albums for $username timed out.');
    } catch (e) {
      Logger.e('Jukebox Service Exception (top albums, $username)', error: e);
    }
    return [];
  }

  Future<List<LovedTrack>> fetchLovedTracks(
    String username, {
    int limit = 10,
    int page = 1,
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) return [];
    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getlovedtracks&user=$username'
        '&limit=$limit&page=$page&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(data['lovedtracks']?['track']);
        if (tracks.isNotEmpty) {
          return tracks.map(LovedTrack.fromJson).toList();
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        Logger.e(
          'Jukebox Service Error (loved, $username): ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Loved tracks for $username timed out.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception (loved, $username)', error: e);
    }
    return [];
  }

  Future<List<MusicStatus>> fetchRecentTracksRange(
    String username, {
    int limit = 50,
    required int from,
    required int to,
    int page = 1,
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) return [];
    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getrecenttracks&user=$username'
        '&from=$from&to=$to&limit=$limit&page=$page&format=json',
      );
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(
          data['recenttracks']?['track'],
        ).where((t) => t['date'] != null).toList();
        if (tracks.isNotEmpty) {
          return tracks
              .map((t) => MusicStatus.fromTrackJson(t, username))
              .toList();
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        Logger.e(
          'Jukebox Service Error (recent range, $username): ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Recent range for $username timed out.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception (recent range, $username)', error: e);
    }
    return [];
  }

  Future<List<MusicStatus>> fetchTrackScrobbles(
    String username, {
    required String artist,
    required String track,
    int limit = 50,
    int page = 1,
  }) async {
    final result = await _fetchTrackScrobblesPage(
      username,
      artist: artist,
      track: track,
      limit: limit,
      page: page,
    );
    return result.scrobbles;
  }

  Future<({List<MusicStatus> scrobbles, int rawCount, int? totalPages})>
  _fetchTrackScrobblesPage(
    String username, {
    required String artist,
    required String track,
    int limit = 50,
    int page = 1,
  }) async {
    const empty = (scrobbles: <MusicStatus>[], rawCount: 0, totalPages: null);
    if (username.isEmpty ||
        artist.isEmpty ||
        track.isEmpty ||
        _invalidUsers.contains(username)) {
      return empty;
    }

    ({List<MusicStatus> scrobbles, int rawCount, int? totalPages}) done(
      List<MusicStatus> scrobbles,
      int rawCount, {
      int? totalPages,
    }) => (
      scrobbles: scrobbles,
      rawCount: rawCount,
      totalPages: totalPages,
    );

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettrackscrobbles&user=$username'
        '&artist=${Uri.encodeComponent(artist)}'
        '&track=${Uri.encodeComponent(track)}'
        '&limit=$limit&page=$page&format=json',
      );

      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final node = data['trackscrobbles'];
        final sections = node is Map ? node['@attr'] : null;
        final totalPages = sections is Map
            ? int.tryParse(sections['totalPages']?.toString() ?? '')
            : null;
        final tracks = _asMapList(node is Map ? node['track'] : null);
        if (tracks.isNotEmpty) {
          return done(
            tracks
                .where((t) => t['date'] != null)
                .map((t) => MusicStatus.fromTrackJson(t, username))
                .toList(),
            tracks.length,
            totalPages: totalPages,
          );
        }
      } else if (response.statusCode == 404) {
        _markInvalidUser(username);
      } else {
        Logger.w(
          'Jukebox Service: Track scrobbles ($username, $artist - $track) status ${response.statusCode}',
        );
      }
    } on TimeoutException {
      Logger.w(
        'Jukebox Service Timeout: Track scrobbles for "$artist - $track" ($username) timed out.',
      );
    } catch (e) {
      Logger.w(
        'Jukebox Service Exception (track scrobbles, $artist - $track, $username)',
        error: e,
      );
    }
    return empty;
  }

  Future<List<MusicStatus>> fetchTrackScrobblesAll(
    String username, {
    required String artist,
    required String track,
    int pageSize = 200,
    int maxScrobbles = 2000,
  }) async {
    final all = <MusicStatus>[];
    final maxPages = (maxScrobbles / pageSize).ceil();
    for (var page = 1; page <= maxPages; page++) {
      final result = await _fetchTrackScrobblesPage(
        username,
        artist: artist,
        track: track,
        limit: pageSize,
        page: page,
      );
      all.addAll(result.scrobbles);
      if (_invalidUsers.contains(username)) break;
      final totalPages = result.totalPages;
      if (totalPages != null) {
        if (page >= totalPages) break;
        continue;
      }
      if (result.rawCount < pageSize) break;
    }
    return all;
  }

  Future<List<MusicStatus>> fetchArtistHistory(
    String username, {
    required String artist,
    List<String> knownTracks = const [],
    int maxTracks = 12,
    int scrobblesPerTrack = 200,
    bool includeRecent = true,
  }) async {
    final trimmedArtist = artist.trim();
    if (username.isEmpty ||
        trimmedArtist.isEmpty ||
        _invalidUsers.contains(username)) {
      return [];
    }

    final wantedArtist = trimmedArtist.toLowerCase();
    final allScrobbles = <MusicStatus>[];

    final uniqueTracks = <String>[];
    final seenTracks = <String>{};
    for (final t in knownTracks) {
      final name = t.trim();
      final key = name.toLowerCase();
      if (name.isNotEmpty && seenTracks.add(key)) {
        uniqueTracks.add(name);
        if (maxTracks > 0 && uniqueTracks.length >= maxTracks) break;
      }
    }

    final recentFuture = () async {
      if (!includeRecent) return const <MusicStatus>[];
      try {
        final recent = await fetchRecentTracks(username, limit: 200);
        return recent
            .where(
              (t) =>
                  t.artistName.trim().toLowerCase() == wantedArtist &&
                  t.timestamp != null,
            )
            .toList();
      } catch (e) {
        Logger.w(
          'Jukebox Service: Error fetching recent tracks for artist $trimmedArtist',
          error: e,
        );
        return const <MusicStatus>[];
      }
    }();

    const batchSize = 5;
    for (var i = 0; i < uniqueTracks.length; i += batchSize) {
      if (_invalidUsers.contains(username)) break;
      final batch = uniqueTracks.skip(i).take(batchSize);
      final results = await Future.wait(
        batch.map(
          (track) => fetchTrackScrobblesAll(
            username,
            artist: trimmedArtist,
            track: track,
            pageSize: scrobblesPerTrack,
          ),
        ),
      );
      for (final list in results) {
        allScrobbles.addAll(list);
      }
    }

    allScrobbles.addAll(await recentFuture);

    final deduplicated = <MusicStatus>[];
    final seenScrobbles = <String>{};
    for (final s in allScrobbles) {
      final ts = s.timestamp?.millisecondsSinceEpoch ?? 0;
      final key = '${s.trackName.trim().toLowerCase()}|$ts';
      if (seenScrobbles.add(key)) {
        deduplicated.add(s);
      }
    }

    deduplicated.sort((a, b) {
      final aTs = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final bTs = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });

    return deduplicated;
  }

  Future<List<LovedTrack>> fetchLovedTracksLegacyAlias(
    String u, {
    int limit = 10,
  }) => fetchLovedTracks(u, limit: limit);

  static String _normalizeForMatch(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
  }
}
