import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/logger.dart';

class PlayerMemory {
  final String? providerId;
  final int? season;
  final int? episode;
  final int? positionSeconds;
  final String? server;
  final String? audio;
  final double? volume;

  const PlayerMemory({
    this.providerId,
    this.season,
    this.episode,
    this.positionSeconds,
    this.server,
    this.audio,
    this.volume,
  });

  Map<String, dynamic> toJson() => {
    if (providerId != null) 'providerId': providerId,
    if (season != null) 'season': season,
    if (episode != null) 'episode': episode,
    if (positionSeconds != null) 'positionSeconds': positionSeconds,
    if (server != null) 'server': server,
    if (audio != null) 'audio': audio,
    if (volume != null) 'volume': volume,
  };

  factory PlayerMemory.fromJson(Map<String, dynamic> json) {
    return PlayerMemory(
      providerId: json['providerId'] as String?,
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      positionSeconds: (json['positionSeconds'] as num?)?.toInt(),
      server: json['server'] as String?,
      audio: json['audio'] as String?,
      volume: (json['volume'] as num?)?.toDouble(),
    );
  }

  PlayerMemory merge({
    String? providerId,
    int? season,
    int? episode,
    int? positionSeconds,
    bool clearPosition = false,
    String? server,
    String? audio,
    double? volume,
  }) {
    return PlayerMemory(
      providerId: providerId ?? this.providerId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      positionSeconds: clearPosition
          ? null
          : (positionSeconds ?? this.positionSeconds),
      server: server ?? this.server,
      audio: audio ?? this.audio,
      volume: volume ?? this.volume,
    );
  }
}

class PlayerMemoryService {
  static final PlayerMemoryService _instance =
      PlayerMemoryService._internal();
  factory PlayerMemoryService() => _instance;
  PlayerMemoryService._internal();

  static const _prefix = 'player_memory_v1/';
  static const _globalKey = '${_prefix}global';
  static const double defaultVolume = 1.0;

  static String cinemaKey({
    required int id,
    required String mediaType,
    required bool isAnime,
  }) => '$_prefix${isAnime ? 'mal' : 'tmdb'}/$id/$mediaType';

  static String animexKey({int? anilistId, required int malId}) =>
      '$_prefix${'animex/${anilistId ?? malId}'}';

  static String watchPartyKey(String roomId) => '${_prefix}party/$roomId';

  Future<PlayerMemory> load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return _withGlobalVolume(prefs, null);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return _withGlobalVolume(prefs, null);
      }
      return _withGlobalVolume(prefs, PlayerMemory.fromJson(json));
    } catch (e, st) {
      Logger.e(
        'PlayerMemory: load failed for $key (resume point lost)',
        error: e,
        stackTrace: st,
      );
      return const PlayerMemory();
    }
  }

  Future<void> save(
    String key, {
    String? providerId,
    int? season,
    int? episode,
    int? positionSeconds,
    bool clearPosition = false,
    String? server,
    String? audio,
    double? volume,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      PlayerMemory current = const PlayerMemory();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          current = PlayerMemory.fromJson(json);
        }
      }
      final next = current.merge(
        providerId: providerId,
        season: season,
        episode: episode,
        positionSeconds: positionSeconds,
        clearPosition: clearPosition,
        server: server,
        audio: audio,
        volume: volume,
      );
      await prefs.setString(key, jsonEncode(next.toJson()));
      if (volume != null) {
        await prefs.setDouble(_globalKey, volume.clamp(0.0, 1.0));
      }
    } catch (e, st) {
      Logger.e(
        'PlayerMemory: save failed for $key (resume point not stored)',
        error: e,
        stackTrace: st,
      );
    }
  }

  PlayerMemory _withGlobalVolume(
    SharedPreferences prefs,
    PlayerMemory? memory,
  ) {
    final global = prefs.getDouble(_globalKey);
    if (memory == null) return PlayerMemory(volume: global);
    if (memory.volume != null) return memory;
    return memory.merge(volume: global);
  }
}
