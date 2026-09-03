import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Posts the current pick to Discord via notifyDiscordWatch.
/// Quiet-fails: returns false and print-logs, cinema stays usable.
class DiscordShareService {
  DiscordShareService({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  Future<bool> share({
    required String idToken,
    required String title,
    required String posterPath,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    try {
      final resp = await _client.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
        body: jsonEncode({
          'title': title,
          'posterPath': posterPath,
          'mediaType': mediaType,
          if (season != null) 'season': season,
          if (episode != null) 'episode': episode,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('DiscordShareService.share failed: ${resp.statusCode} ${resp.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('DiscordShareService.share failed: $e');
      return false;
    }
  }
}
