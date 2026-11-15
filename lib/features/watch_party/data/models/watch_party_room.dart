import 'package:cloud_firestore/cloud_firestore.dart';

class WatchPartyRoom {
  final String id;

  final String name;

  final String hostUid;

  final String hostName;

  final String partnerUid;

  final String partnerName;

  final String mediaType;

  final int tmdbId;

  final int? malId;

  final bool isAnime;

  final int? season;
  final int? episode;

  final String title;
  final String posterPath;

  final String? serverType;

  final String? serverName;

  final String? serverHost;

  final String? streamUrl;

  final String? subtitleUrl;

  final bool captionsOn;

  final int? episodeCount;

  final bool proxyEnabled;

  final String state;

  final double currentTime;

  final DateTime? positionAt;

  final DateTime updatedAt;

  final String updatedBy;

  final String? beatBy;

  final DateTime createdAt;

  final bool active;

  const WatchPartyRoom({
    required this.id,
    this.name = '',
    required this.hostUid,
    required this.hostName,
    required this.partnerUid,
    required this.partnerName,
    required this.mediaType,
    required this.tmdbId,
    this.malId,
    required this.isAnime,
    this.season,
    this.episode,
    this.episodeCount,
    required this.title,
    required this.posterPath,
    this.serverType,
    this.serverName,
    this.serverHost,
    this.streamUrl,
    this.subtitleUrl,
    this.captionsOn = true,
    this.proxyEnabled = false,
    required this.state,
    required this.currentTime,
    this.positionAt,
    required this.updatedAt,
    required this.updatedBy,
    this.beatBy,
    required this.createdAt,
    required this.active,
  });

  bool get hasMedia => tmdbId > 0 || title.isNotEmpty;

  bool get isSeries => mediaType == 'tv';

  bool get isHost =>
      updatedBy.isNotEmpty;
  bool get isPlaying => state == 'playing';
  bool get isPaused => state == 'paused';
  bool get isBuffering => state == 'buffering';

  bool isLive({Duration staleAfter = const Duration(minutes: 15)}) =>
      active && DateTime.now().difference(updatedAt) < staleAfter;

  double livePositionAt(DateTime serverNow) {
    if (state != 'playing') return currentTime;
    final anchor = positionAt ?? updatedAt;
    final elapsed = serverNow.difference(anchor);
    if (elapsed <= Duration.zero) return currentTime;
    if (elapsed > const Duration(seconds: 30)) return currentTime;
    return currentTime + elapsed.inMilliseconds / 1000.0;
  }

  String get formattedCurrentTime =>
      _formatDuration(Duration(milliseconds: (currentTime * 1000).round()));

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String buildRoomId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  factory WatchPartyRoom.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WatchPartyRoom(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      hostUid: (data['hostUid'] as String?) ?? '',
      hostName: (data['hostName'] as String?) ?? '',
      partnerUid: (data['partnerUid'] as String?) ?? '',
      partnerName: (data['partnerName'] as String?) ?? '',
      mediaType: (data['mediaType'] as String?) ?? 'movie',
      tmdbId: _parseInt(data['tmdbId']) ?? 0,
      malId: (data['malId'] is num) ? (data['malId'] as num).toInt() : null,
      isAnime: data['isAnime'] == true,
      season: (data['season'] is num) ? (data['season'] as num).toInt() : null,
      episode: (data['episode'] is num)
          ? (data['episode'] as num).toInt()
          : null,
      episodeCount: (data['episodeCount'] is num)
          ? (data['episodeCount'] as num).toInt()
          : null,
      title: (data['title'] as String?) ?? '',
      posterPath: (data['posterPath'] as String?) ?? '',
      serverType: data['serverType'] as String?,
      serverName: data['serverName'] as String?,
      serverHost: data['serverHost'] as String?,
      streamUrl: data['streamUrl'] as String?,
      subtitleUrl: data['subtitleUrl'] as String?,
      captionsOn: data['captionsOn'] != false,
      proxyEnabled: data['proxyEnabled'] == true,
      state: (data['state'] as String?) ?? 'paused',
      currentTime: (data['currentTime'] as num?)?.toDouble() ?? 0.0,
      positionAt: _parseDateTime(data['positionAt']),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      updatedBy: (data['updatedBy'] as String?) ?? '',
      beatBy: data['beatBy'] as String?,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      active: data['active'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (name.isNotEmpty) 'name': name,
      'hostUid': hostUid,
      'hostName': hostName,
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      if (malId != null) 'malId': malId,
      'isAnime': isAnime,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (episodeCount != null) 'episodeCount': episodeCount,
      'title': title,
      'posterPath': posterPath,
      if (serverType != null) 'serverType': serverType,
      if (serverName != null) 'serverName': serverName,
      if (serverHost != null) 'serverHost': serverHost,
      if (streamUrl != null) 'streamUrl': streamUrl,
      if (subtitleUrl != null) 'subtitleUrl': subtitleUrl,
      'captionsOn': captionsOn,
      'proxyEnabled': proxyEnabled,
      'state': state,
      'currentTime': currentTime,
      if (positionAt != null) 'positionAt': Timestamp.fromDate(positionAt!),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      if (beatBy != null) 'beatBy': beatBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
    };
  }

  WatchPartyRoom copyWith({
    String? name,
    String? mediaType,
    int? tmdbId,
    int? malId,
    bool? isAnime,
    int? season,
    int? episode,
    int? episodeCount,
    String? title,
    String? posterPath,
    String? state,
    double? currentTime,
    DateTime? positionAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? beatBy,
    bool? active,
  }) {
    return WatchPartyRoom(
      id: id,
      name: name ?? this.name,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType ?? this.mediaType,
      tmdbId: tmdbId ?? this.tmdbId,
      malId: malId ?? this.malId,
      isAnime: isAnime ?? this.isAnime,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      episodeCount: episodeCount ?? this.episodeCount,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      serverType: serverType,
      serverName: serverName,
      serverHost: serverHost,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      captionsOn: captionsOn,
      proxyEnabled: proxyEnabled,
      state: state ?? this.state,
      currentTime: currentTime ?? this.currentTime,
      positionAt: positionAt ?? this.positionAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      beatBy: beatBy ?? this.beatBy,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  WatchPartyRoom copyWithMedia({
    required String mediaType,
    required int tmdbId,
    int? malId,
    required bool isAnime,
    int? season,
    int? episode,
    int? episodeCount,
    required String title,
    required String posterPath,
    String? state,
    double? currentTime,
    DateTime? positionAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? active,
  }) {
    return WatchPartyRoom(
      id: id,
      name: name,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType,
      tmdbId: tmdbId,
      malId: malId,
      isAnime: isAnime,
      season: season,
      episode: episode,
      episodeCount: episodeCount,
      title: title,
      posterPath: posterPath,
      serverType: serverType,
      serverName: serverName,
      serverHost: serverHost,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      captionsOn: captionsOn,
      proxyEnabled: proxyEnabled,
      state: state ?? this.state,
      currentTime: currentTime ?? this.currentTime,
      positionAt: positionAt ?? this.positionAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      beatBy: beatBy,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  WatchPartyRoom copyWithCaptions({
    String? subtitleUrl,
    bool? captionsOn,
  }) {
    return WatchPartyRoom(
      id: id,
      name: name,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType,
      tmdbId: tmdbId,
      malId: malId,
      isAnime: isAnime,
      season: season,
      episode: episode,
      episodeCount: episodeCount,
      title: title,
      posterPath: posterPath,
      serverType: serverType,
      serverName: serverName,
      serverHost: serverHost,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      captionsOn: captionsOn ?? this.captionsOn,
      proxyEnabled: proxyEnabled,
      state: state,
      currentTime: currentTime,
      positionAt: positionAt,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      beatBy: beatBy,
      createdAt: createdAt,
      active: active,
    );
  }

  WatchPartyRoom copyWithServer({
    String? serverType,
    String? serverName,
    String? serverHost,
    String? streamUrl,
    String? subtitleUrl,
    bool? proxyEnabled,
  }) {
    return WatchPartyRoom(
      id: id,
      name: name,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType,
      tmdbId: tmdbId,
      malId: malId,
      isAnime: isAnime,
      season: season,
      episode: episode,
      episodeCount: episodeCount,
      title: title,
      posterPath: posterPath,
      serverType: serverType,
      serverName: serverName,
      serverHost: serverHost,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      captionsOn: captionsOn,
      proxyEnabled: proxyEnabled ?? false,
      state: state,
      currentTime: currentTime,
      positionAt: positionAt,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      beatBy: beatBy,
      createdAt: createdAt,
      active: active,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class WatchPartyUpdate {
  final WatchPartyRoom room;
  final DateTime receivedAt;

  final bool isLocal;

  const WatchPartyUpdate({
    required this.room,
    required this.receivedAt,
    required this.isLocal,
  });
}
