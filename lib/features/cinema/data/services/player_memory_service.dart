import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the player remembers for one title.
///
/// Cinema uses [providerId], [season], [episode] and [positionSeconds].
/// AnimeX uses [server], [audio] (`sub`/`dub`) and [episode].
/// [volume] is stored per title so shows mastered at different loudness
/// each reopen at a comfortable level; it falls back to the last-used
/// global volume when a title has none saved yet.
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

/// Remembers per-title player choices on this device so Clair never has
/// to re-pick the server, episode, or volume for a show she already
/// started — especially on the phone, where every episode used to reset.
///
/// Storage is a single JSON blob per title in SharedPreferences.
/// Firestore watch progress stays the cross-device source of truth for
/// season/episode/position; this is the fast local comfort layer on top,
/// and the only place the picked provider/server lives.
class PlayerMemoryService {
  static final PlayerMemoryService _instance =
      PlayerMemoryService._internal();
  factory PlayerMemoryService() => _instance;
  PlayerMemoryService._internal();

  static const _prefix = 'player_memory_v1/';
  static const _globalKey = '${_prefix}global';
  static const double defaultVolume = 1.0;

  /// Key for a cinema title. Anime items are keyed by MAL id (the id the
  /// cinema player actually navigates with), everything else by TMDB id.
  static String cinemaKey({
    required int id,
    required String mediaType,
    required bool isAnime,
  }) => '$_prefix${isAnime ? 'mal' : 'tmdb'}/$id/$mediaType';

  /// Key for an AnimeX title. Prefers the AniList id, falls back to MAL.
  static String animexKey({int? anilistId, required int malId}) =>
      '$_prefix${'animex/${anilistId ?? malId}'}';

  /// Key for a watch-party room (volume only — the room owns the rest).
  static String watchPartyKey(String roomId) => '${_prefix}party/$roomId';

  /// Loads the saved memory for [key], or an empty memory when nothing
  /// was saved yet. Never throws — a corrupt blob reads as empty.
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
    } catch (_) {
      return const PlayerMemory();
    }
  }

  /// Merges the given fields into the saved memory for [key].
  /// Only non-null arguments overwrite what is already stored, except
  /// [clearPosition] which drops a stale resume point (episode change).
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
      // Volume doubles as the global fallback for titles without one.
      if (volume != null) {
        await prefs.setDouble(_globalKey, volume.clamp(0.0, 1.0));
      }
    } catch (_) {
      // Memory is best-effort comfort; never break playback over it.
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
