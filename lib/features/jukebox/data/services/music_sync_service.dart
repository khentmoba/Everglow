import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/config/env_config.dart';
import '../models/music_status.dart';
import '../models/top_music_track.dart';
import '../models/lastfm_image_utils.dart';
import '../../../../core/utils/logger.dart';

class MusicSyncService {
  MusicSyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _apiKey => EnvConfig.lastfmApiKey;
  final String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  // Usernames that Last.fm reported as invalid (HTTP 404 / error code 6
  // "User not found"). Once we know a username is bad we stop hitting the
  // API for it so the 30-second poll doesn't spam the console with errors
  // and trigger downstream "Another exception was thrown" cascades.
  static final Set<String> _invalidUsers = <String>{};

  bool isUserInvalid(String username) => _invalidUsers.contains(username);

  /// Resets the invalid-user cache (e.g. if a user later creates an account).
  static void resetInvalidUsers() => _invalidUsers.clear();

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
    if (_apiKey.isEmpty) {
      Logger.w('Jukebox Service: API Key is missing!');
      return [];
    }

    if (username.isEmpty || _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getrecenttracks&user=$username&api_key=$_apiKey&format=json&limit=$limit',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['recenttracks']?['track'];
        if (tracks is List && tracks.isNotEmpty) {
          return tracks
              .map(
                (track) => MusicStatus.fromTrackJson(
                  track as Map<String, dynamic>,
                  username,
                ),
              )
              .toList();
        } else {
          Logger.d('Jukebox Service: No tracks found for $username in response.');
        }
      } else if (response.statusCode == 404) {
        // Last.fm returns 404 with `{"error": 6, "message": "User not found"}`
        // for usernames that don't exist (e.g. placeholders in env.txt).
        // Mark the user as invalid so we never poll for them again this
        // session and just surface a quiet empty state in the UI.
        _invalidUsers.add(username);
        Logger.w('Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.');
      } else {
        Logger.e('Jukebox Service Error ($username): Status ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      Logger.e('Jukebox Service Timeout: API call for $username timed out after 10s.');
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
    if (_apiKey.isEmpty) {
      Logger.w('Jukebox Service: API Key is missing!');
      return [];
    }

    if (username.isEmpty || _invalidUsers.contains(username)) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.gettoptracks&user=$username&period=$period'
        '&limit=$limit&api_key=$_apiKey&format=json',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['toptracks']?['track'];
        if (tracks is List && tracks.isNotEmpty) {
          final parsed = <TopMusicTrack>[];
          for (var i = 0; i < tracks.length; i++) {
            final track = TopMusicTrack.fromJson(
              tracks[i] as Map<String, dynamic>,
            );
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
                    ),
            );
          }
          return parsed;
        } else {
          Logger.d('Jukebox Service: No top tracks found for $username in response.');
        }
      } else if (response.statusCode == 404) {
        _invalidUsers.add(username);
        Logger.w('Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.');
      } else {
        Logger.e('Jukebox Service Error (top tracks, $username): Status ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      Logger.e('Jukebox Service Timeout: Top tracks API call for $username timed out after 10s.');
    } catch (e) {
      Logger.e('Jukebox Service Exception (top tracks, $username)', error: e);
    }
    return [];
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
    if (_apiKey.isEmpty) {
      Logger.w('Jukebox Service: API Key is missing!');
      return null;
    }

    try {
      final buffer = StringBuffer(
        '$_baseUrl?method=track.getinfo&api_key=$_apiKey&format=json',
      );
      if (mbid != null && mbid.isNotEmpty) {
        buffer.write('&mbid=${Uri.encodeComponent(mbid)}');
      } else {
        buffer.write(
          '&artist=${Uri.encodeComponent(artist)}'
          '&track=${Uri.encodeComponent(track)}',
        );
      }

      final response = await _client
          .get(Uri.parse(buffer.toString()))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final album = data['track']?['album'];
        if (album is Map) {
          final images = album['image'] as List<dynamic>?;
          if (images != null && images.isNotEmpty) {
            dynamic selectedImage = images.last;
            for (final img in images) {
              if (img is Map && img['size'] == 'extralarge') {
                selectedImage = img;
                break;
              }
            }
            if (selectedImage is Map) {
              return cleanLastfmImageUrl(selectedImage['#text'] as String?);
            }
          }
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
  /// Queries `artist + track` first. Last.fm sometimes stores mangled names
  /// (UTF-8 mojibake of accented names), which can make
  /// the combined query return nothing, so the search is retried with just
  /// the track name. Prefers the result whose track name matches exactly
  /// (ignoring case and punctuation) so a cover is never paired with the
  /// wrong song.
  Future<String?> _fetchItunesArtwork({
    required String artist,
    required String track,
  }) async {
    try {
      var results = await _searchItunes('$artist $track');
      if (results.isEmpty) {
        results = await _searchItunes(track);
      }
      if (results.isEmpty) return null;

      final selected = _selectItunesResult(results, track);
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
    final uri = Uri.parse('https://itunes.apple.com/search').replace(
      queryParameters: {
        'term': term,
        'entity': 'song',
        'media': 'music',
        'limit': '10',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];
    final data = json.decode(response.body);
    final results = data is Map<String, dynamic> ? data['results'] : null;
    if (results is! List) return const [];
    return results.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic>? _selectItunesResult(
    List<Map<String, dynamic>> results,
    String track,
  ) {
    if (results.isEmpty) return null;
    final normalizedTrack = _normalizeForMatch(track);
    for (final result in results) {
      final resultTrack = result['trackName'];
      if (resultTrack is String &&
          _normalizeForMatch(resultTrack) == normalizedTrack) {
        return result;
      }
    }
    return results.first;
  }

  /// Lowercases and strips punctuation for forgiving title comparisons.
  static String _normalizeForMatch(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  }
}
