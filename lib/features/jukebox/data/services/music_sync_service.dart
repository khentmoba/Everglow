import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/config/env_config.dart';
import '../models/music_status.dart';

class MusicSyncService {
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
    if (_apiKey.isEmpty) {
      print('Jukebox Service: API Key is missing!');
      return null;
    }

    if (username.isEmpty || _invalidUsers.contains(username)) {
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?method=user.getrecenttracks&user=$username&api_key=$_apiKey&format=json&limit=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['recenttracks'] != null &&
            data['recenttracks']['track'] != null &&
            (data['recenttracks']['track'] as List).isNotEmpty) {
          return MusicStatus.fromJson(data, username);
        } else {
          print('Jukebox Service: No tracks found for $username in response.');
        }
      } else if (response.statusCode == 404) {
        // Last.fm returns 404 with `{"error": 6, "message": "User not found"}`
        // for usernames that don't exist (e.g. placeholders in env.txt).
        // Mark the user as invalid so we never poll for them again this
        // session and just surface a quiet empty state in the UI.
        _invalidUsers.add(username);
        print('Jukebox Service: Last.fm user "$username" not found. Skipping future polls this session.');
      } else {
        print('Jukebox Service Error ($username): Status ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      print('Jukebox Service Timeout: API call for $username timed out after 10s.');
    } catch (e) {
      print('Jukebox Service Exception ($username): $e');
    }
    return null;
  }
}
