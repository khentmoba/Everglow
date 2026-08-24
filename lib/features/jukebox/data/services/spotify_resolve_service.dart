import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/logger.dart';
import '../models/music_status.dart';

/// Resolves a [MusicStatus] search URL to a real Spotify track via Cloud Function.
///
/// The function `proxySpotifySearch` uses Client Credentials, so the user does
/// not need to have linked Spotify. Returns a copy of [status] with
/// `spotifyTrackId`/`spotifyEmbedUrl` populated, or the original status on failure.
class SpotifyResolveService {
  SpotifyResolveService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  // Generic Cloud Function base — falls back to hosting rewrite when emulator not used.
  String get _base {
    const host = String.fromEnvironment('FUNCTIONS_HOST', defaultValue: '');
    if (host.isNotEmpty) return host;
    return 'https://us-central1-everglow-1c6db.cloudfunctions.net';
  }

  /// Resolves via GET /proxySpotifySearch?artist=&track=
  Future<MusicStatus> resolve(MusicStatus status) async {
    // Already resolved or empty sentinel
    if (status.hasSpotifyTrack || status.trackName == 'Silent Night') {
      return status;
    }
    if (status.artistName.isEmpty || status.trackName.isEmpty) return status;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return status;
      final uri = Uri.parse('$_base/proxySpotifySearch').replace(
        queryParameters: {
          'artist': status.artistName,
          'track': status.trackName,
        },
      );
      final res = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        // Try hosting rewrite path
        final alt = Uri.parse('/api/proxySpotifySearch').replace(
          queryParameters: {
            'artist': status.artistName,
            'track': status.trackName,
          },
        );
        final res2 = await _client
            .get(alt, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 10));
        if (res2.statusCode != 200) return status;
        return _apply(status, json.decode(res2.body));
      }
      return _apply(status, json.decode(res.body));
    } on TimeoutException {
      Logger.w(
        'SpotifyResolve timeout for ${status.artistName} - ${status.trackName}',
      );
      return status;
    } catch (e) {
      Logger.w('SpotifyResolve error: $e');
      return status;
    }
  }

  MusicStatus _apply(MusicStatus s, dynamic data) {
    if (data is! Map) return s;
    final id = data['trackId'] as String?;
    if (id == null || id.isEmpty) return s;
    return s.copyWith(
      spotifyTrackId: id,
      spotifyEmbedUrl: data['embedUrl'] as String?,
      previewUrl: data['previewUrl'] as String?,
      spotifyUrl: data['spotifyUrl'] as String?,
      // Prefer Spotify artwork if Last.fm was missing
      imageUrl: s.imageUrl ?? data['imageUrl'] as String?,
    );
  }
}
