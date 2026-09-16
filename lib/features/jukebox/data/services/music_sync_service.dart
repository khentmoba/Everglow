import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/artist_suggestion.dart';
import '../models/loved_track.dart';
import '../models/music_status.dart';
import '../models/top_album.dart';
import '../models/top_artist.dart';
import '../models/top_music_track.dart';
import '../models/lastfm_image_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';

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

  /// Last.fm requests are signed and proxied server-side so the API key is
  /// never embedded in the Flutter web bundle.
  final String _baseUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfm';

  // ── Process-wide token cache shared across JukeboxProvider + MusicStatsProvider ──
  // Without this, 8 concurrent proxyLastfm calls on dashboard boot each pay
  // `getIdToken()` independently, serializing behind the auth bridge.
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
    if (signUrl != null) {
      final signed = await signUrl(url);
      return _client.get(signed).timeout(const Duration(seconds: 10));
    }
    final token = await _getTokenCached();
    if (token == null || token.isEmpty) {
      throw StateError('Last.fm requires an authenticated user');
    }
    return _client
        .get(url, headers: {'Authorization': "Bearer $token"})
        .timeout(const Duration(seconds: 10));
  }

  // Usernames that Last.fm reported as invalid (HTTP 404 / error code 6
  // "User not found"). Once we know a username is bad we stop hitting the
  // API for it so the 30-second poll doesn't spam the console with errors
  // and trigger downstream "Another exception was thrown" cascades.
  static final Set<String> _invalidUsers = <String>{};

  bool isUserInvalid(String username) => _invalidUsers.contains(username);

  /// Resets the invalid-user cache (e.g. if a user later creates an account).
  static void resetInvalidUsers() => _invalidUsers.clear();

  /// Normalizes a Last.fm list node to maps. Last.fm collapses a
  /// single-element list to a bare object, so an `is List` check alone
  /// would drop a user's only result.
  List<Map<String, dynamic>> _asMapList(dynamic node) {
    if (node is List) return node.whereType<Map<String, dynamic>>().toList();
    if (node is Map<String, dynamic>) return [node];
    if (node is Map) return [Map<String, dynamic>.from(node)];
    return const [];
  }

  /// Last.fm reports failures (rate limit, temp error, offline) as HTTP 200
  /// with an `error` payload, which the proxy forwards untouched. Without
  /// this check those are indistinguishable from "user has no scrobbles",
  /// so they are logged loudly instead of as a quiet empty state.
  void _warnOnLastfmError(dynamic data, String what, String username) {
    final error = data is Map ? data['error'] : null;
    final message = data is Map ? data['message'] : null;
    if (error != null || message != null) {
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

  /// Fetches the [limit] most recent scrobbles for [username].
  ///
  /// The first entry may carry a `nowplaying` flag instead of a timestamp
  /// when the user is currently listening. Returns an empty list when the
  /// user is unknown, the API key is missing, or the request fails.
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
        final tracks = _asMapList(data['recenttracks']?['track']);
        if (tracks.isNotEmpty) {
          return tracks
              .map(
                (track) => MusicStatus.fromTrackJson(track, username),
              )
              .toList();
        } else {
          _warnOnLastfmError(data, 'tracks', username);
        }
      } else if (response.statusCode == 404) {
        // Last.fm returns 404 with `{"error": 6, "message": "User not found"}`
        // for usernames that don't exist (e.g. placeholders in env.txt).
        // Mark the user as invalid so we never poll for them again this
        // session and just surface a quiet empty state in the UI.
        _invalidUsers.add(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.',
        );
      } else {
        Logger.e(
          'Jukebox Service Error ($username): Status ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: API call for $username timed out after 10s.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception ($username)', error: e);
    }
    return [];
  }

  /// Fetches the user's most-played tracks from Last.fm.
  ///
  /// [period] defaults to `overall` (all-time stats). Returns an empty list
  /// when the user is unknown, the API key is missing, or the request fails.
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async {
    if (username.isEmpty || _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettoptracks&user=$username&period=$period'
        '&limit=$limit&format=json',
      );

      final response = await _getWithAuth(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = _asMapList(data['toptracks']?['track']);
        if (tracks.isNotEmpty) {
          final parsed = <TopMusicTrack>[];
          for (var i = 0; i < tracks.length; i++) {
            final track = TopMusicTrack.fromJson(tracks[i]);
            // Last.fm includes a rank, but fall back to the list order so
            // the leaderboard always renders 1..10.
            parsed.add(
              track.rank > 0
                  ? track
                  : TopMusicTrack(
                      rank: i + 1,
                      trackName: track.trackName,
                      artistName: track.artistName,
                      playCount: track.playCount,
                      imageUrl: track.imageUrl,
                      spotifyUrl: track.spotifyUrl,
                      mbid: track.mbid,
                    ),
            );
          }
          return parsed;
        } else {
          _warnOnLastfmError(data, 'top tracks', username);
        }
      } else if (response.statusCode == 404) {
        _invalidUsers.add(username);
        Logger.w(
          'Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.',
        );
      } else {
        Logger.e(
          'Jukebox Service Error (top tracks, $username): Status ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      Logger.e(
        'Jukebox Service Timeout: Top tracks API call for $username timed out after 10s.',
      );
    } catch (e) {
      Logger.e('Jukebox Service Exception (top tracks, $username)', error: e);
    }
    return [];
  }

  /// Deprecated: `user.getartisttracks` was deprecated by Last.fm in 2019
  /// (stale legacy backend, entries carry no `playcount`). Kept for tests
  /// and backwards compat — new code should pull `user.gettoptracks`
  /// (limit 1000) and filter by artist locally, as ArtistShowdownProvider
  /// now does.
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
        _invalidUsers.add(username);
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
      Logger.e('Jukebox Service Exception (artist tracks, $username)', error: e);
    }
    return [];
  }

  /// Fetches the user's all-time scrobble count via `user.getInfo`.
  ///
  /// Returns 0 when the user is unknown, the key is missing, or the request
  /// fails. The caller should fall back to summing local top-track playCounts
  /// when this returns 0 so the UI still shows a meaningful total.
  Future<int> fetchUserTotalPlays(String username) async {
    if (username.isEmpty || _invalidUsers.contains(username)) return 0;
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
          if (parsed != null && parsed > 0) return parsed;
        }
      } else if (response.statusCode == 404) {
        _invalidUsers.add(username);
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
    return 0;
  }

  /// Looks up real album artwork for a single track via `track.getinfo`.
  ///
  /// `user.gettoptracks` frequently returns Last.fm's default placeholder
  /// image (or no image at all), so the dashboard enriches missing covers
  /// with the track's actual album art. Prefers the MusicBrainz [mbid] when
  /// available, otherwise falls back to artist + track lookup. When Last.fm
  /// still has no usable cover, the iTunes Search API is queried as a final
  /// fallback (it reliably carries artwork for independent and mainstream
  /// releases alike). Returns null when every lookup fails.
  ///
  /// Matching is deliberately strict: a cover is only returned when the
  /// lookup result is verifiably the SAME song (title and artist, ignoring
  /// case and punctuation). A missing cover falls back to the music-note
  /// tile, which is always better than pairing a row with the wrong song's
  /// art — e.g. the base "Crush" cover must never land on "Crush -
  /// Stripped".
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
    return _fetchItunesArtwork(artist: artist, track: track);
  }

  Future<String?> _fetchLastfmTrackArtwork({
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
        // Last.fm can fuzzy-match the query to a different track (e.g.
        // "Crush - Stripped" resolving to "Crush"). Only accept the
        // album art when the returned song is verifiably the requested one.
        if (trackNode is Map &&
            _matchesTrack(
              trackNode['name'],
              _artistNameOf(trackNode['artist']),
              track: track,
              artist: artist,
            )) {
          final album = trackNode['album'];
          if (album is Map) {
            final picked = pickLastfmImageUrl(
              album['image'] as List<dynamic>?,
            );
            if (picked != null) return picked;
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

  /// Fallback artwork lookup via the iTunes Search API (no key required).
  ///
  /// Queries `artist + track` first and only accepts a result whose title
  /// AND artist both match (ignoring case and punctuation). Last.fm
  /// sometimes stores mangled names (UTF-8 mojibake of accented names),
  /// which can make the combined query return nothing, so the search is
  /// retried with just the track name — but the retry still requires an
  /// exact title match, and for clean ASCII artist names the artist must
  /// match too. (Mangled names are unverifiable by nature, so the artist
  /// check is skipped only when the name contains non-ASCII characters.)
  /// Returns null rather than guessing: no `results.first` fallback, so a
  /// cover is never paired with the wrong song.
  Future<String?> _fetchItunesArtwork({
    required String artist,
    required String track,
  }) async {
    try {
      final results = await _searchItunes('$artist $track');
      var selected = _selectItunesResult(
        results,
        track: track,
        artist: artist,
      );
      if (selected == null && results.isEmpty) {
        final retry = await _searchItunes(track);
        selected = _selectItunesResult(
          retry,
          track: track,
          // A mangled Last.fm artist name can never match iTunes' clean
          // one, so only verifiable (ASCII) names keep the artist check.
          artist: _hasNonAscii(artist) ? null : artist,
        );
      }
      if (selected == null) return null;
      final artwork = selected['artworkUrl100'];
      if (artwork is! String || artwork.isEmpty) return null;

      // artworkUrl100 is 100x100; bump it to 600x600 so covers stay crisp in
      // the large listen-along dialog and the dashboard rows.
      return artwork.replaceFirst('/100x100bb.jpg', '/600x600bb.jpg');
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

  Future<List<Map<String, dynamic>>> _searchItunes(String term) async {
    final query = {
      'term': term,
      'entity': 'song',
      'media': 'music',
      'limit': '10',
    };
    http.Response response;
    if (kIsWeb) {
      // Direct browser calls to itunes.apple.com redirect to musics:// and
      // get blocked by browser CORS policy. Route through proxyCatalog.
      response = await _proxy.get(
        'itunes',
        'search',
        query: query,
        timeout: const Duration(seconds: 8),
      );
    } else {
      final uri = Uri.parse('https://itunes.apple.com/search').replace(
        queryParameters: query,
      );
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
    // No exact match: return null so the row falls back to the music-note
    // tile. Never guess with `results.first` — near-misses (the base
    // "Crush" for "Crush - Stripped", or another artist's same-titled
    // song) are exactly how wrong covers end up on leaderboard rows.
    return null;
  }

  /// True when the candidate title (and, when [artist] is given, the
  /// candidate artist) identify the requested song. Comparison ignores case
  /// and punctuation so "Crush – Stripped" still matches "Crush -
  /// Stripped", but version suffixes and different artists never match.
  bool _matchesTrack(
    dynamic candidateTrack,
    dynamic candidateArtist, {
    required String track,
    String? artist,
  }) {
    if (candidateTrack is! String) return false;
    if (_normalizeForMatch(candidateTrack) != _normalizeForMatch(track)) {
      return false;
    }
    if (artist == null) return true;
    if (candidateArtist is! String) return false;
    return _normalizeForMatch(candidateArtist) == _normalizeForMatch(artist);
  }

  /// Reads a Last.fm artist node, which is normally `{"name": ...}` but
  /// is occasionally a bare string in older responses.
  static String? _artistNameOf(dynamic artistNode) {
    if (artistNode is Map) {
      final name = artistNode['name'];
      return name is String ? name : null;
    }
    return artistNode is String ? artistNode : null;
  }

  /// True when [value] contains non-ASCII characters — the telltale sign of
  /// either a genuinely accented name or Last.fm UTF-8 mojibake, both of
  /// which make byte-level artist comparison against iTunes unreliable.
  static bool _hasNonAscii(String value) =>
      value.runes.any((rune) => rune > 127);

  /// Searches Last.fm's global artist catalog for autocomplete.
  ///
  /// Powers the Artist Showdown search dropdown: type "lana del" and pick
  /// "Lana Del Rey" instead of guessing the exact spelling. Returns an
  /// empty list for short/blank queries or on any failure so the UI simply
  /// shows no dropdown.
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
      Logger.e(
        'Jukebox Service Exception (artist search, $trimmed)',
        error: e,
      );
    }
    return const [];
  }

  /// Fetches the user's most-played artists from Last.fm.
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
        _invalidUsers.add(username);
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

  /// Fetches the user's most-played albums from Last.fm.
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
        _invalidUsers.add(username);
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

  /// Fetches the user's loved tracks from Last.fm.
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
        _invalidUsers.add(username);
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

  /// Fetches recent tracks in a specific timestamp window (used for heatmap / OTD).
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
        final tracks = _asMapList(data['recenttracks']?['track'])
            .where((t) => t['date'] != null)
            .toList();
        if (tracks.isNotEmpty) {
          return tracks
              .map((t) => MusicStatus.fromTrackJson(t, username))
              .toList();
        }
      } else if (response.statusCode == 404) {
        _invalidUsers.add(username);
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

  // Alias for provider compatibility (older name).
  Future<List<LovedTrack>> fetchLovedTracksLegacyAlias(
    String u, {
    int limit = 10,
  }) => fetchLovedTracks(u, limit: limit);

  /// Lowercases and strips punctuation for forgiving title comparisons.
  static String _normalizeForMatch(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
  }
}
