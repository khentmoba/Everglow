import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/config/env_config.dart';
import '../models/music_status.dart';

class MusicSyncService {
  String get _apiKey => EnvConfig.lastfmApiKey;
  final String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  Future<MusicStatus?> fetchRecentTrack(String username) async {
    if (_apiKey.isEmpty) {
      print('Jukebox Service: API Key is missing!');
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
          final track = data['recenttracks']['track'][0];
          final trackName = track['name'];
          final isLive = track['@attr']?['nowplaying'] == 'true';
          // print('Jukebox Service: Received data for $username. Track: $trackName. Now playing: $isLive');
          return MusicStatus.fromJson(data, username);
        } else {
          print('Jukebox Service: No tracks found for $username in response.');
        }
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
